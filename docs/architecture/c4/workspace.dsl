workspace "Sportcut" "Turns one badminton recording into a highlight video on the user's Mac. No cloud, no telemetry, no online API." {

    model {

        # --- L1: the person and the system -------------------------------------

        editor = person "Editor" "Imports a recording, marks the court, confirms rallies and the score, exports a highlight." {
            tags "Person"
        }

        sportcut = softwareSystem "Sportcut" "Turns one badminton recording into a highlight video on this Mac." {
            tags "Internal"

            # --- L2: containers and data stores --------------------------------

            app = container "Flutter client" "Library, studio, playback, and the protocol client. Links no Rust." "Dart 3 · Riverpod · app/" {
                tags "App"

                group "Feature folders" {
                    analysis = component "analysis" "Artifact badges and rebuild state." "feature · app/lib/src/features/analysis" {
                        properties {
                            "path" "app/lib/src/features/analysis"
                        }
                    }
                    calibration = component "calibration" "Mark the court; render the engine's outline and net." "feature · app/lib/src/features/calibration" {
                        properties {
                            "path" "app/lib/src/features/calibration"
                        }
                    }
                    editing = component "editing" "Score timeline and edit-list data." "feature · app/lib/src/features/editing" {
                        properties {
                            "path" "app/lib/src/features/editing"
                        }
                    }
                    exportFeature = component "export" "Export settings and start." "feature · app/lib/src/features/export" {
                        properties {
                            "path" "app/lib/src/features/export"
                        }
                    }
                    highlights = component "highlights" "Ranking and reel assembly." "feature · app/lib/src/features/highlights" {
                        properties {
                            "path" "app/lib/src/features/highlights"
                        }
                    }
                    library = component "library" "Match library, repository, import." "feature · app/lib/src/features/library" {
                        properties {
                            "path" "app/lib/src/features/library"
                        }
                    }
                    rallyFeature = component "rally" "Rally review and boundaries." "feature · app/lib/src/features/rally" {
                        properties {
                            "path" "app/lib/src/features/rally"
                        }
                    }
                    scoreFeature = component "score" "Score entry and serving sides." "feature · app/lib/src/features/score" {
                        properties {
                            "path" "app/lib/src/features/score"
                        }
                    }
                    tracking = component "tracking" "Player tracking overlay and panel." "feature · app/lib/src/features/tracking" {
                        properties {
                            "path" "app/lib/src/features/tracking"
                        }
                    }
                    workspaceFeature = component "workspace" "Studio shell, stage strip, playback." "feature · app/lib/src/features/workspace" {
                        properties {
                            "path" "app/lib/src/features/workspace"
                        }
                    }
                }

                group "Bridge" {
                    sportcutEngine = component "SportcutEngine" "Typed engine API. The only place the app knows the service exists." "app/lib/src/bridge/sportcut_engine.dart" {
                        properties {
                            "path" "app/lib/src/bridge/sportcut_engine.dart"
                        }
                    }
                    serviceConnection = component "ServiceConnection" "Unix socket, framing, request correlation, handshake." "app/lib/src/bridge/protocol_client.dart" {
                        properties {
                            "path" "app/lib/src/bridge/protocol_client.dart"
                        }
                    }
                    models = component "Models" "Typed DTOs mirrored from the protocol." "app/lib/src/bridge/models.dart" {
                        properties {
                            "path" "app/lib/src/bridge/models.dart"
                        }
                    }
                }

                group "Design system" {
                    design = component "Design system" "Tokens, metrics, typography, and shared components." "app/lib/src/app/design" {
                        properties {
                            "path" "app/lib/src/app/design"
                        }
                    }
                }

                group "App shell" {
                    shell = component "App shell" "Startup, dependency injection, routing." "app/lib/src/app · di/router" {
                        properties {
                            "path" "app/lib/src/app/di.dart"
                        }
                    }
                }
            }

            service = container "SportcutService" "Background process. Owns media processing, analysis, jobs, the catalog, and export." "Rust · core/adapters/service" {
                tags "Service"

                group "Adapters" {
                    serviceHost = component "Service host" "Process host: Unix socket, peer UID, single-instance lock, job loop, cancellation." "sportcut-service · core/adapters/service" {
                        properties {
                            "crate" "sportcut-service"
                        }
                    }
                    api = component "Engine facade" "The library the host calls. Orchestrates the use cases." "sportcut-api · core/adapters/api" {
                        properties {
                            "crate" "sportcut-api"
                        }
                    }
                }

                group "Gateways + contracts" {
                    wireProtocol = component "Wire contract" "Method names, DTOs, error codes, framing, version negotiation." "sportcut-protocol · core/gateways/protocol" {
                        properties {
                            "crate" "sportcut-protocol"
                        }
                    }
                    storage = component "Storage adapter" "Catalog, artifacts, recording store. Implements ports declared by the use cases." "sportcut-storage · core/gateways/storage" {
                        properties {
                            "crate" "sportcut-storage"
                        }
                    }
                }

                group "Use cases" {
                    jobs = component "Jobs" "Job model, one heavy job at a time, checkpoints, resume." "sportcut-jobs" {
                        properties {
                            "crate" "sportcut-jobs"
                        }
                    }
                    media = component "Media" "Probe, proxy, audio, frames through the media toolchain." "sportcut-media" {
                        properties {
                            "crate" "sportcut-media"
                        }
                    }
                    vision = component "Vision" "Court and player detection; TFLite is optional." "sportcut-vision" {
                        properties {
                            "crate" "sportcut-vision"
                        }
                    }
                    export = component "Export" "Edit list and render." "sportcut-export" {
                        properties {
                            "crate" "sportcut-export"
                        }
                    }
                    eval = component "Evaluation" "Segmentation and ranking evaluation." "sportcut-eval" {
                        properties {
                            "crate" "sportcut-eval"
                        }
                    }
                }

                group "Entities" {
                    common = component "Common" "Shared types. Every crate may use it." "sportcut-common" {
                        properties {
                            "crate" "sportcut-common"
                        }
                    }
                    court = component "Court" "Homography, validation, net projection." "sportcut-court" {
                        properties {
                            "crate" "sportcut-court"
                        }
                    }
                    rally = component "Rally" "Rally segmentation." "sportcut-rally" {
                        properties {
                            "crate" "sportcut-rally"
                        }
                    }
                    score = component "Score" "Score and serving rules." "sportcut-score" {
                        properties {
                            "crate" "sportcut-score"
                        }
                    }
                    highlight = component "Highlight" "Highlight ranking." "sportcut-highlight" {
                        properties {
                            "crate" "sportcut-highlight"
                        }
                    }
                }

                group "Developer entry point" {
                    cli = component "CLI driver" "Developer entry point. Not shipped in the app." "sportcut-cli · core/drivers/cli" {
                        properties {
                            "crate" "sportcut-cli"
                            "excluded" "true"
                        }
                    }
                }
            }

            state = container "State root" "Catalog (schema v6 target), recordings in custody, artifacts, run/ and logs/." "SQLite + files" {
                tags "Database"
            }

            clientCatalog = container "Client v5 catalog" "The app's own catalog and recording copy until ADR-0001 Phase 4 retires them." "SQLite · interim" {
                tags "Database,Interim"
            }
        }

        recordings = softwareSystem "Recording files" "The recording the user picked. Sportcut copies it into custody and never modifies the original." {
            tags "External"
        }

        avfoundation = softwareSystem "AVFoundation" "Plays the recording and its proxy in the client." {
            tags "External"
        }

        ffmpeg = softwareSystem "ffmpeg / ffprobe" "Probe, proxy, audio, frames, and export. Required at runtime." {
            tags "External"
        }

        tflite = softwareSystem "TFLite runtime + model" "Player tracking only. Absent when the build omits macos-tflite-eval." {
            tags "External"
        }

        # --- L1 relationships ---------------------------------------------------

        editor -> sportcut "Imports a recording, marks the court, confirms rallies and the score, exports" "UI"

        sportcut -> recordings "Copies the selected file into custody; never modifies the original" "filesystem"

        sportcut -> avfoundation "Plays the recording and the proxy" "macOS framework"

        # --- L2 relationships ---------------------------------------------------

        editor -> app "Imports a recording, marks the court, reviews rallies, exports" "UI"

        app -> service "Sends protocol methods" "JSON-RPC over a Unix socket · Protocol v1"

        app -> avfoundation "Plays the recording and the proxy" "macOS framework"

        app -> clientCatalog "Reads and writes its own v5 catalog" "SQLite"

        service -> state "Owns the catalog, recording custody, jobs, and artifacts" "SQLite + filesystem"

        service -> recordings "Copies the selected file into custody; never modifies the original" "filesystem"

        service -> ffmpeg "Resolves the binaries; media and export run them" "CLI"

        service -> tflite "Runs player tracking when macos-tflite-eval is on" "C API"

        # --- L3 service: compile-time dependencies ------------------------------
        # These mirror the path dependencies in core/Cargo.toml. Edges to
        # sportcut-common and from sportcut-cli are omitted so the picture shows
        # the structure rather than fourteen identical arrows to common;
        # tools/check-c4-model.sh enforces the same exclusion on both sides.

        serviceHost -> api "Calls the facade"

        serviceHost -> wireProtocol "Frames requests"

        serviceHost -> media "Probes the media toolchain"

        api -> court "Projects the court"

        api -> export "Renders the edit list"

        api -> highlight "Ranks highlights"

        api -> jobs "Runs jobs"

        api -> media "Runs media work"

        api -> rally "Segments rallies"

        api -> score "Keeps the score"

        api -> storage "Reads and writes state"

        api -> vision "Runs detection"

        eval -> rally "Evaluates segmentation"

        eval -> vision "Evaluates detection"

        export -> media "Runs ffmpeg through the media crate"

        storage -> court "Stores court types"

        storage -> jobs "Implements the job port"

        storage -> media "Implements the media port"

        storage -> rally "Implements the rally port"

        vision -> court "Reads the projected court"

        storage -> state "Writes the catalog and artifacts" "SQLite + filesystem"

        media -> ffmpeg "Runs probe, proxy, audio, and frames" "CLI"

        vision -> tflite "Loads the runtime and the person model" "C API"

        # --- L3 client ----------------------------------------------------------

        analysis -> sportcutEngine "Calls the typed engine API"

        calibration -> sportcutEngine "Calls the typed engine API"

        exportFeature -> sportcutEngine "Calls the typed engine API"

        highlights -> sportcutEngine "Calls the typed engine API"

        library -> sportcutEngine "Calls the typed engine API"

        rallyFeature -> sportcutEngine "Calls the typed engine API"

        scoreFeature -> sportcutEngine "Calls the typed engine API"

        tracking -> sportcutEngine "Calls the typed engine API"

        workspaceFeature -> sportcutEngine "Calls the typed engine API"

        sportcutEngine -> serviceConnection "Sends protocol methods"

        sportcutEngine -> models "Decodes results into typed models"

        shell -> design "Builds the theme from tokens"

        library -> clientCatalog "Reads and writes the interim catalog" "SQLite"
    }

    views {

        systemContext sportcut "l1-system-context" {
            include *
            autolayout
        }

        container sportcut "l2-containers" {
            include *
            autolayout
        }

        component service "l3-components-service" {
            include *
            include state
            include ffmpeg
            include tflite
            exclude cli
            autolayout
        }

        component app "l3-components-client" {
            include *
            include clientCatalog
            autolayout
        }
    }
}
