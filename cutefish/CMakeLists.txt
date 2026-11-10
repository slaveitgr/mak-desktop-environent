cmake_minimum_required(VERSION 3.22)
project(makos_cutefish LANGUAGES C CXX)
set(CMAKE_CXX_STANDARD 17)
set(CMAKE_AUTOMOC ON)
find_package(Qt6 6.8 REQUIRED COMPONENTS Core Gui Qml WaylandClient DBus)
find_package(PkgConfig REQUIRED)
pkg_check_modules(WAYLAND REQUIRED IMPORTED_TARGET wayland-client)
qt_add_library(makoscutefish MODULE integration.cpp shell_surface.h shell_state.h)
target_link_libraries(makoscutefish PRIVATE Qt6::Core Qt6::Gui Qt6::GuiPrivate Qt6::Qml Qt6::WaylandClient Qt6::DBus PkgConfig::WAYLAND)
qt_generate_wayland_protocol_client_sources(makoscutefish FILES
    "${CMAKE_CURRENT_SOURCE_DIR}/protocols/cutefish-shell-v1.xml"
    "${CMAKE_CURRENT_SOURCE_DIR}/protocols/cutefish-main-menu-v1.xml"
    "${CMAKE_CURRENT_SOURCE_DIR}/protocols/cutefish-surface-blur-v1.xml"
    "${CMAKE_CURRENT_SOURCE_DIR}/protocols/cutefish-window-hints-v1.xml")
set_target_properties(makoscutefish PROPERTIES LIBRARY_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/qml/MakOS/Cutefish")
file(MAKE_DIRECTORY "${CMAKE_BINARY_DIR}/qml/MakOS/Cutefish")
configure_file(qmldir "${CMAKE_BINARY_DIR}/qml/MakOS/Cutefish/qmldir" COPYONLY)
install(TARGETS makoscutefish LIBRARY DESTINATION lib/makos/qml/MakOS/Cutefish)
install(FILES qmldir DESTINATION lib/makos/qml/MakOS/Cutefish)

add_subdirectory(settings)
add_subdirectory(auth)
