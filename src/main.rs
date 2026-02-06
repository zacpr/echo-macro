/**
 * Echo Macro - OpenDeck Plugin
 * 
 * This plugin types pre-recorded text when a Stream Deck button is pressed.
 * Uses ydotool for Wayland/X11 compatibility.
 * 
 * Flatpak compatible: Detects sandbox and uses flatpak-spawn to access host ydotool.
 */

use openaction::{
    init_plugin,
    ActionEventHandler,
    GlobalEventHandler,
    KeyEvent,
    AppearEvent,
    DidReceiveSettingsEvent,
    OutboundEventManager,
    EventHandlerResult,
};
use serde::{Deserialize, Serialize};
use std::process::Command;
use std::env;
use log::{info, debug, error};
use anyhow::Result;

/**
 * Settings struct - Configuration data for our action.
 */
#[derive(Serialize, Deserialize, Debug, Clone, Default)]
struct TypeTextSettings {
    #[serde(default)]
    text: String,
}

/// Mask text for privacy in logs
/// - If <= 10 chars: show first char only (e.g., "H...")
/// - If > 10 chars: show first + 15 asterisks + last (e.g., "H***************d")
/// 
/// NOTE: This is best-effort only. Debug mode may expose raw text via SDK logging.
fn mask_text(text: &str) -> String {
    let len = text.chars().count();
    if len == 0 {
        return "(empty)".to_string();
    }
    if len <= 10 {
        let first = text.chars().next().unwrap();
        return format!("{}... ({} chars)", first, len);
    }
    // > 10 chars: first + 15 asterisks + last
    let first = text.chars().next().unwrap();
    let last = text.chars().last().unwrap();
    format!("{}***************{} ({} chars)", first, last, len)
}

struct EchoMacroHandler {
    is_flatpak: bool,
}

impl EchoMacroHandler {
    fn new() -> Self {
        // Detect if running inside Flatpak sandbox
        let has_flatpak_id = env::var("FLATPAK_ID").is_ok();
        let has_flatpak_info = std::path::Path::new("/.flatpak-info").exists();
        let is_flatpak = has_flatpak_id || has_flatpak_info;
        
        debug!("FLATPAK_ID present: {}, /.flatpak-info exists: {}", has_flatpak_id, has_flatpak_info);
        
        if is_flatpak {
            info!("Echo Macro handler created (Flatpak mode - using flatpak-spawn)");
        } else {
            info!("Echo Macro handler created (native mode - using ydotool directly)");
        }
        
        EchoMacroHandler { is_flatpak }
    }
    
    /// Type text using ydotool (works on both Wayland and X11)
    /// Returns true on success, false on failure
    fn type_text(&self, settings: &TypeTextSettings) -> bool {
        // Use default text if none configured
        let text = if settings.text.is_empty() {
            "Hello World"
        } else {
            &settings.text
        };
        
        // Mask text for privacy in logs
        let masked = mask_text(text);
        info!("Typing: {}", masked);
        
        // Type with ydotool
        match self.type_with_ydotool(text) {
            Ok(()) => {
                info!("Finished typing successfully");
                true
            }
            Err(_) => {
                error!("Failed to type text - ydotool error");
                false
            }
        }
    }
    
    /// Spawn ydotool to type text
    /// Uses flatpak-spawn --host when running inside Flatpak
    /// Returns Ok(()) on success, Err(()) on failure
    fn type_with_ydotool(&self, text: &str) -> Result<(), ()> {
        // Note: ydotool doesn't have a per-character delay option like xdotool
        // It types all at once. For now we ignore delay_ms.
        let output = if self.is_flatpak {
            // Running inside Flatpak - use flatpak-spawn to access host binaries
            Command::new("flatpak-spawn")
                .args(&["--host", "ydotool", "type", text])
                .output()
        } else {
            // Native mode - run ydotool directly
            Command::new("ydotool")
                .args(&["type", text])
                .output()
        };
            
        match output {
            Ok(result) => {
                if !result.status.success() {
                    let stderr = String::from_utf8_lossy(&result.stderr);
                    error!("ydotool failed: {}", stderr);
                    
                    if stderr.contains("ydotoold") || stderr.contains("socket") || stderr.contains("connection") {
                        error!("ydotoold daemon may not be running!");
                        error!("Try: systemctl start ydotoold (or run ydotoold in a terminal)");
                    }
                    if stderr.contains("flatpak-spawn") || stderr.contains("not found") {
                        error!("flatpak-spawn may not be available!");
                        error!("The Flatpak needs --talk-name=org.freedesktop.Flatpak permission");
                    }
                    Err(())
                } else {
                    debug!("ydotool completed successfully");
                    Ok(())
                }
            }
            Err(e) => {
                error!("Failed to spawn ydotool: {}", e);
                if self.is_flatpak {
                    error!("Make sure ydotool is installed on the HOST system");
                    error!("Also check: flatpak override --user --talk-name=org.freedesktop.Flatpak me.amankhanna.opendeck");
                } else {
                    error!("Make sure ydotool is installed: sudo apt install ydotool");
                }
                Err(())
            }
        }
    }
}

impl ActionEventHandler for EchoMacroHandler {
    fn key_down(
        &self,
        event: KeyEvent,
        outbound: &mut OutboundEventManager,
    ) -> impl std::future::Future<Output = EventHandlerResult> + Send {
        let settings: TypeTextSettings = serde_json::from_value(event.payload.settings)
            .unwrap_or_default();
        let context = event.context;
        
        async move {
            info!("Key pressed!");
            debug!("Settings: {:?}", settings);
            
            if !self.type_text(&settings) {
                // Show alert indicator on the action button
                if let Err(e) = outbound.show_alert(context).await {
                    error!("Failed to show alert: {}", e);
                }
            }
            
            Ok(())
        }
    }

    fn key_up(
        &self,
        _event: KeyEvent,
        _outbound: &mut OutboundEventManager,
    ) -> impl std::future::Future<Output = EventHandlerResult> + Send {
        async move { Ok(()) }
    }

    fn will_appear(
        &self,
        event: AppearEvent,
        _outbound: &mut OutboundEventManager,
    ) -> impl std::future::Future<Output = EventHandlerResult> + Send {
        let context = event.context;
        async move {
            info!("Action appeared: {}", context);
            Ok(())
        }
    }

    fn will_disappear(
        &self,
        event: AppearEvent,
        _outbound: &mut OutboundEventManager,
    ) -> impl std::future::Future<Output = EventHandlerResult> + Send {
        let context = event.context;
        async move {
            info!("Action disappeared: {}", context);
            Ok(())
        }
    }

    fn did_receive_settings(
        &self,
        event: DidReceiveSettingsEvent,
        _outbound: &mut OutboundEventManager,
    ) -> impl std::future::Future<Output = EventHandlerResult> + Send {
        let context = event.context;
        async move {
            debug!("Received new settings for: {}", context);
            Ok(())
        }
    }
}

struct EchoMacroGlobalHandler;

impl GlobalEventHandler for EchoMacroGlobalHandler {
    fn plugin_ready(
        &self,
        _outbound: &mut OutboundEventManager,
    ) -> impl std::future::Future<Output = EventHandlerResult> + Send {
        async move {
            let is_flatpak = env::var("FLATPAK_ID").is_ok() 
                || std::path::Path::new("/.flatpak-info").exists();
            
            if is_flatpak {
                info!("Echo Macro plugin connected! Running in Flatpak mode.");
                info!("Will use flatpak-spawn --host to access ydotool");
            } else {
                info!("Echo Macro plugin connected! Running in native mode.");
            }
            info!("Using ydotool for Wayland/X11 compatibility.");
            
            // Test if ydotool is available (ydotool doesn't have --version, use 'help')
            let test_cmd = if is_flatpak {
                Command::new("flatpak-spawn")
                    .args(&["--host", "ydotool", "help"])
                    .output()
            } else {
                Command::new("ydotool")
                    .arg("help")
                    .output()
            };
            
            match test_cmd {
                Ok(result) => {
                    if result.status.success() {
                        info!("ydotool is available");
                    } else {
                        let stderr = String::from_utf8_lossy(&result.stderr);
                        error!("ydotool returned error: {}", stderr);
                    }
                }
                Err(e) => {
                    error!("Failed to run ydotool: {}", e);
                    if is_flatpak {
                        error!("Make sure ydotool is installed on the HOST system");
                        error!("You may also need to grant Flatpak permission:");
                        error!("  flatpak override --user --talk-name=org.freedesktop.Flatpak me.amankhanna.opendeck");
                    } else {
                        error!("Install ydotool: sudo apt install ydotool");
                    }
                }
            }
            
            Ok(())
        }
    }
}

#[tokio::main]
async fn main() -> Result<()> {
    simplelog::SimpleLogger::init(
        simplelog::LevelFilter::Debug,
        simplelog::Config::default()
    )?;
    
    info!("Echo Macro plugin starting...");
    
    let global_handler = EchoMacroGlobalHandler;
    let action_handler = EchoMacroHandler::new();
    
    init_plugin(global_handler, action_handler).await?;
    
    info!("Plugin shutting down");
    Ok(())
}
