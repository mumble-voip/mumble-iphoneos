This source snapshot comes from the user's complete libmumble checkout at
`10a62f66e44b0b8df466b5d8390869b3f9c11d46` (Switch to ipxx), from
https://github.com/mumble-voip/libmumble.

Application integration changes:
- Use standard C++ threads instead of Boost in the runtime. Upstream stress tests
  still use Boost, available through the vcpkg `tests` feature.
- Pin a modern dependency baseline for OpenSSL, Opus and Protobuf.
- Add iOS packaging and platform/runtime fixes required by the application.
- Fix DER certificate initialization/parsing, UTC date conversion, UDP audio
  direction decoding, unaligned OCB buffers, authentication tag bounds,
  connection timeout initialization, SNI, TLS mode configuration and read-ahead.
- Allow bounded control messages up to 8 MiB rather than truncating the protocol
  to 64 KiB, so avatars and long text messages can be received.

The original sibling checkout is preserved. Update this snapshot deliberately;
do not overwrite local integration changes with an unreviewed source copy.
