//! `sportcut-service`: the background helper process.
//!
//! The app launches this binary with explicit arguments; it serves the
//! lifecycle methods and, through the Phase 1 engine adapter, all 17
//! `engine.*` methods over the Unix domain socket. Catalog and custody methods
//! remain `method_not_found` until a later phase fills them in.

use std::process::ExitCode;

use sportcut_service::config::{parse_args, Parsed, USAGE};
use sportcut_service::{BindResult, Server};

fn main() -> ExitCode {
    match run() {
        Ok(()) => ExitCode::SUCCESS,
        Err(error) => {
            eprintln!("sportcut-service: {error:#}");
            ExitCode::FAILURE
        }
    }
}

fn run() -> anyhow::Result<()> {
    match parse_args(std::env::args_os().skip(1))? {
        Parsed::Help => {
            print!("{USAGE}");
            Ok(())
        }
        Parsed::Version => {
            println!("sportcut-service {}", env!("CARGO_PKG_VERSION"));
            Ok(())
        }
        Parsed::Run(config) => match Server::bind(config)? {
            BindResult::Started(server) => server.run(),
            BindResult::AlreadyRunning { endpoint } => {
                // background-service §4.2: a second launch reports the existing
                // endpoint and exits successfully so the client can connect.
                println!(
                    "sportcut-service is already running; connecting to {}",
                    endpoint.display()
                );
                Ok(())
            }
        },
    }
}
