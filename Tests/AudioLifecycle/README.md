# Audio session lifecycle regression tests

Build the Debug Simulator app, boot an arm64 iOS 27 Simulator, then run:

```sh
bash Scripts/test-audio-lifecycle.sh /path/to/Debug-iphonesimulator/Mumble.app
```

The runner copies the application into a separate bundle and loads a test-only
library. It exercises the application's compiled MLAudio implementation, replacing
AVAudioSession with delayed callbacks and engine creation/resumption with test
counters. It
does not connect to a server or use a microphone. No test code is loaded by the
normal app.

The capture-queue regression uses a fake input node and engine while running the
real tap, pooled PCM handoff, converter and Opus encoder. It checks mute/unmute,
retired callbacks, input-format changes and cancellation of the coalesced dispatch
source. Speaking-state tests cover immediate activation, a 300 ms visual release
delay, resumed speech, mute, lost terminators and model reset. Voice transmission
does not wait for the visual delay.

The standalone memory/FIFO tests need no Simulator or audio hardware:

```sh
bash Scripts/test-audio-buffers.sh
```

These verify four-buffer reuse over 100,000 callbacks, full-queue protection,
oversized-buffer slicing, interleaved/planar stereo and concurrent producer/consumer
ordering. Playback buffers are retained until playback completion and then reused;
each source's free pool is capped at 24 buffers.

Checks include duplicate starts, stop during activation, restart during activation,
start during deactivation, interruptions with and without permission to resume,
activation failure, configuration failure, late permission grants, and deactivation
failure, engine stops after hardware configuration changes, off-main recovery
without session reactivation, duplicate and stale recovery events, bounded repeated
failures, callbacks that do not retain retiring engines, sustained idle capture
intent, transient input-format startup failures, and cancellation of a pending
startup retry. Configuration and synchronous
session calls must never run on the main thread. On iOS 27 the asynchronous system
API must be used. Callback completion is deliberately delivered from a background
queue. The script prints results and fails if a check fails or times out.

Graph tests hold the DSP queue and pause construction while issuing stop/start
requests. They assert main-thread responsiveness, retirement before deactivation,
and rejection of stale completions. Six consecutive construction failures exhaust
the initial attempt plus five retries; no implicit retry loop may follow, while
a later explicit start gets a fresh budget. Settings tests cover live volume,
bitrate, packet duration and transmission updates, coalesced changes, and route
changes during both session activation and graph construction.
The PCM-to-Opus test also starts an engine whose running-state snapshot lags its
successful start result. Capture must continue and send an encoded packet instead
of being incorrectly torn down as a startup failure.

The interface audit also exercises the connection owner without a real server:
joined-only capture demand, stale authentication/errors, reconnect during initial
presentation, stable delegate ownership, cancellation, and suppression of old
page actions and terminal alerts after a replacement connection starts.
Self-signed certificate checks use the app's tab/navigation containment and
complete server sync while a certificate or Connecting alert is still leaving.
Both first-time trust and remembered-trust reconnects must show the joined server.

To exercise synchronous session activation on the same Simulator, pass `legacy`
as the second argument. The fixture overrides only the audio object's API policy;
the application's compiled background activation/deactivation code still runs.
The fake synchronous APIs block the session queue until the test releases them,
checking that the main thread remains available and ordering is preserved.

Incoming-voice checks deliberately block the main thread, verify that DSP still
receives frames, and cover batched speaking updates, local-mute races, bounded
queues and reconnect cancellation. All transport and decoding probes are local.

To additionally check the older-SDK preprocessor guards, create a temporary
prefix header containing:

```objc
#import <UIKit/UIKit.h>
#undef __IPHONE_OS_VERSION_MAX_ALLOWED
#define __IPHONE_OS_VERSION_MAX_ALLOWED 260200
```

Build into a separate derived data directory with `GCC_PREFIX_HEADER` set to that
header's absolute path and `GCC_PRECOMPILE_PREFIX_HEADER=NO`. Importing UIKit first
prevents SDK imports from restoring the current version macro. Then pass `legacy`
as the second argument to the runner. This additional build checks that the
older-SDK preprocessor guards compile without the new APIs.

The runner requires an iOS 27 Simulator; it does not validate physical audio
hardware, routes, or a real older-iOS runtime.
