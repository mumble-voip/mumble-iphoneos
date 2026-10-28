# libmumble iOS backend

The application uses its own Objective-C interface (`MLClient.h`) and modern
libmumble implementations. There is no MumbleKit runtime, build target, protocol
runtime or audio dependency. Existing views use `MLConnection`, `MLServerModel`,
`MLUser`, `MLChannel`, `MLCertificate`, `MLTextMessage` and `MLAudio`.

- `MLConnection.mm`: cancellable transport, DNS/IPv4/IPv6, libmumble TLS,
  certificate verification through the iOS trust store, client keychain identities,
  certificate-bound overrides, authentication, control messages, encrypted UDP,
  UDP resynchronization and TCP voice fallback. It supports both pre-1.5 and
  1.5+ Opus wire formats. Credentials are withheld until certificate verification
  or acceptance completes. Models and delegate events run on the main thread;
  each connection's network state and outgoing queue are isolated from reconnects.
- `MLModels.mm`: application models based on generated Protobuf messages. Field
  presence is preserved for incremental updates. Delegates are weak references.
- `MLCertificate.mm`: libmumble certificate parsing, SHA-256 signatures for new
  RSA-2048 identities, legacy identity import, PKCS12 export and fingerprints.
  SHA-1 fingerprints remain available for existing server trust records.
  Transfers to Security.framework use a compatible PKCS12 envelope and a random
  transient password. The original certificate and private key are preserved;
  old SHA-1 identities and new SHA-256 identities are tested through mutual TLS.
  This also avoids empty-password system import failures. Apple's PKCS12 format
  constraints are discussed in [Apple Developer Forums](https://developer.apple.com/forums/thread/723242).
- `MLAudio.mm`: AVAudioEngine, microphone permission, route and interruption
  handling, conversion to 48 kHz mono, libmumble Opus, Apple Voice Processing
  (echo cancellation, noise suppression and automatic gain control),
  VAD/PTT/continuous transmission, side tone,
  playback for multiple users, loss concealment and bounded playback queues.
  Each speaker has a small adaptive jitter buffer with a 20–80 ms target,
  bounded packet count/age, duplicate filtering and ordered playout. Empty
  end markers cannot replace speech at the same sequence. Large timing shifts
  rebuffer instead of accumulating delay. Pending playout is cancelled on mute,
  deafen, engine teardown and connection replacement.
- `MLServerPinger.mm`: background IPv4/IPv6 UDP server queries with the
  interoperable legacy public ping format.

Opus is the only voice codec. Legacy CELT/Speex codec preferences are mapped to
Opus. Encoding defaults to the VoIP preset; the optional Low-Delay Encoding
switch selects Opus's CELT-only low-delay preset. The old force-CELT default is
not carried into the new setting. Apple Voice Processing is the same public
processing API used by FaceTime and Phone, as explained in
[WWDC23](https://developer.apple.com/videos/play/wwdc2023/10235/); this does not
reproduce FaceTime's codec or network protocol. Settings expose the system
Standard, Voice Isolation and Wide Spectrum microphone mode panel; availability
depends on the device and audio route. The optional SNR detector only analyses
a PCM copy and never applies a second denoiser or AGC to the transmitted audio.
Manual microphone boost applies only with native processing disabled.
Application audio preferences and the keychain/database are retained.

The source snapshot and integration changes are documented in
`Dependencies/libmumble/UPSTREAM.md`. The generated XCFramework includes static dependency libraries and
headers and is rebuilt using `Scripts/build-libmumble.sh`.

## Validation

`Scripts/test-libmumble.sh` builds a native macOS backend harness with a simulated
audio device. It validates certificate generation/import/export and rejection,
certificate gating/pinning/rotation, TLS SNI, login/tokens, channel updates,
fragmented and large control messages, public server pings, new and legacy Opus
send/receive, TCP fallback, and OCB nonce/replay/tamper behavior. It requires no
external service or real identity. This does not validate microphone hardware.
Speaking-indicator checks wait for the actual timer-driven state change with a
bounded deadline. A separate case deliberately delays the main queue across the
timer deadline, covering scheduler delays on hosted CI runners.
Additional cases verify network handoff, cancellation, backoff limits and
unacknowledged mute intent. Real loopback TLS servers close a live connection,
verify automatic reauthentication and channel/mute restoration with a new
session ID, then verify that certificate rotation, authentication rejection and
server kicks terminate recovery.

## Connection recovery

The app enables automatic recovery after joining a server. A Network.framework
path monitor handles Wi-Fi/cellular changes; transport failures also initiate
recovery. Retries use backoff, at most six attempts and a three-minute recovery
window. An unavailable network pauses connection attempts. Explicit disconnect,
authentication rejection, a changed/untrusted certificate, an unsupported codec,
and removal by the server stop recovery. The existing model, conversation and
draft remain attached. Channel restoration falls back to the server's assigned
channel if the old channel no longer exists; permissions remain server-controlled.
Push-to-talk is released during recovery.

Server certificate trust and Recent use the same trimmed, lowercase hostname.
Legacy mixed-case records, including Unicode LAN names, remain readable. Ports
and different hostnames stay independent; conflicting legacy pins require an
explicit decision. Saving trust replaces equivalent name variants atomically.

`MUConnectionController` owns connection events for the entire session, including
recovery. Its explicit states distinguish connecting, authentication, certificate
and credential decisions, joined sessions, recovery and disconnection. Views do
not take over the transport delegate. Microphone demand begins after server sync
and persists during recovery; opening a socket or a password prompt does not
start capture. Authentication, trust lookups and saved connection history use
background database work. Attempt identities discard obsolete completions.
`MUConnectionPresentation` coordinates UIKit transitions separately, so cancelling
or replacing a connection cannot bring back an old prompt or error.

## Server credentials

`MUCredentialStore` stores favourite passwords and access tokens as generic
Keychain items with `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly` and no
iCloud synchronization. Background reconnects can use them after first unlock;
they do not migrate to another device through a backup. Accounts include an
installation-specific database namespace, avoiding reused favourite IDs after
reinstallation. Passwords are keyed by stable favourite ID; tokens use a
case-normalized host/port endpoint.

Legacy SQL credentials are copied and verified before clearing their old rows.
Unavailable Keychain writes preserve the legacy data for retry. An existing
Keychain value takes precedence over a stale SQL copy following an interrupted
save. Secure deletion and a one-time database rebuild clear historical plaintext
pages after migration succeeds. New credential writes never fall back to SQL.
The signed Simulator interface audit checks real Keychain attributes, migration,
failure preservation, repeated migration and deletion.

## Idle resource use

The transport waits for socket readiness or an explicit outgoing/cancellation
wakeup instead of polling every 20 ms. After server synchronization, a quiet
connection sends keepalives every 15 seconds; authentication and active voice
use 5 seconds. The integration harness checks quiet keepalives, connection
survival and prompt delivery of queued messages.

Microphone capture remains active while connected. VAD continues inspecting
quiet input. PTT release and local mute can skip copying and DSP when no visible
level meter needs input. Conversion and encoding buffers are reused, capture
backlog is bounded, and playback cleanup runs only while playback nodes exist.
Returning to the foreground, unmuting or pressing PTT can request audio recovery
even if an interruption-ended notification never arrives. Requests coalesce;
failed activation does not start a retry loop, and disconnect cancels recovery.
Server-list pings and level meters stop when their views leave the window or
the app enters the background.

The main thread owns audio intent and explicit engine/session states; graph
construction, teardown and DSP run on a serial background queue. Stopping capture
invalidates pending work immediately, then retires the old graph before releasing
the session. Starts, interruptions and setting changes during retirement are
reconciled afterward. Generation checks prevent old startup/recovery completions
from resurrecting a stopped engine. Startup gets at most five retries, and stays
stopped after exhaustion until a new explicit request.

Volume, bitrate, packet duration, transmission mode and VAD changes apply live.
Voice processing, receiver routing, low-delay codec configuration and adding or
removing side tone rebuild the graph. Updates coalesce, and changes during
activation or graph construction settle on the latest configuration before
publishing a running state.

`Scripts/test-audio-lifecycle.sh /path/to/Mumble.app` runs the audio lifecycle
and capture harness against a Simulator build. It covers interruption handling,
activation cancellation, bounded recovery, VAD/PTT capture demand, conversion
buffer reuse, packet sequencing, nonblocking graph transitions and setting-change
races. The optional `legacy` argument exercises the synchronous session API on a
background queue; an additional older-SDK guard build is documented in
`Tests/AudioLifecycle/README.md`.

For physical-device energy measurements, keep a server connected with the app
in the foreground, nobody speaking and microphone capture running. Check the
audio interruption/engine state alongside Xcode's CPU and Energy gauges; a
stopped microphone or disconnected server is not a valid quiet-capture sample.

On physical devices, verify a real server conversation over UDP and forced TCP,
speaker/receiver/Bluetooth routing, PTT/VAD, self-mute/deafen, side tone, background
voice and phone-call interruptions. Confirm that denying microphone permission
still allows browsing and text chat.
