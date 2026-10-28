cmake_minimum_required(VERSION 3.24)
project(MumbleBackendTests LANGUAGES C CXX OBJCXX)
set(CMAKE_CXX_STANDARD 20)
set(CMAKE_OBJCXX_STANDARD 20)
set(LIBMUMBLE_BUILD_TESTS OFF CACHE BOOL "" FORCE)
set(LIBMUMBLE_BUILD_EXAMPLES OFF CACHE BOOL "" FORCE)
set(LIBMUMBLE_STATIC ON CACHE BOOL "" FORCE)
find_package(Protobuf CONFIG REQUIRED)
find_package(OpenSSL REQUIRED)
add_subdirectory(../../Dependencies/libmumble libmumble)
add_executable(MumbleBackendTests
    MLBackendTests.mm
    MLReconnectTests.mm
    ../../Source/LibMumble/MLConnection.mm
    ../../Source/LibMumble/MLCertificate.mm
    ../../Source/LibMumble/MLModels.mm
    ../../Source/LibMumble/MLServerPinger.mm)
target_compile_options(MumbleBackendTests PRIVATE -fobjc-arc)
target_include_directories(MumbleBackendTests PRIVATE ../../Source/LibMumble "${CMAKE_CURRENT_BINARY_DIR}/libmumble/src/proto")
target_link_libraries(MumbleBackendTests PRIVATE Mumble::libmumble protobuf::libprotobuf OpenSSL::SSL OpenSSL::Crypto "-framework Foundation" "-framework Security" "-framework Network")
enable_testing()
add_test(NAME MumbleBackendTests COMMAND MumbleBackendTests)
set_tests_properties(MumbleBackendTests PROPERTIES TIMEOUT 60 ENVIRONMENT "TZ=Pacific/Honolulu")
add_test(NAME MumbleTalkIndicatorsDelayed COMMAND MumbleBackendTests --delayed-talk-indicators)
set_tests_properties(MumbleTalkIndicatorsDelayed PROPERTIES TIMEOUT 15)

add_test(NAME MumbleReconnectPolicy COMMAND MumbleBackendTests --reconnect-policy)
set_tests_properties(MumbleReconnectPolicy PROPERTIES TIMEOUT 15)

add_test(NAME MumbleReconnectTransport COMMAND MumbleBackendTests --reconnect-transport)
set_tests_properties(MumbleReconnectTransport PROPERTIES TIMEOUT 45)
