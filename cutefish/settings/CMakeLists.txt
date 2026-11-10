# Reuse the libraries linked by the original cutefish-settings application.
find_package(CutefishClients REQUIRED COMPONENTS audio networkmanager bluez powerprofiles upower display)
add_executable(makos-settings-backend main.cpp)
set_target_properties(makos-settings-backend PROPERTIES CXX_STANDARD 20 AUTOMOC OFF)
target_link_libraries(makos-settings-backend PRIVATE Qt6::Core Cutefish::AudioClient
    Cutefish::NetworkManagerClient Cutefish::BluezClient Cutefish::PowerProfilesClient
    Cutefish::UPowerClient Cutefish::DisplayClient)
install(TARGETS makos-settings-backend RUNTIME DESTINATION lib/makos)
