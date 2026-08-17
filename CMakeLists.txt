cmake_minimum_required(VERSION 3.10)
project(music-for-nas-synology.puqsoftware LANGUAGES CXX)

set(APP_NAME "music-for-nas-synology.puqsoftware")
set(DESKTOP_FILE "music-for-nas-synology.desktop")
set(APPARMOR_FILE "apparmor.json")
set(MANIFEST_FILE "manifest.json")
set(ICON_FILE "music-for-nas-synology.png")

set(CMAKE_CXX_STANDARD 11)
set(CMAKE_AUTOMOC ON)

find_package(Qt5 REQUIRED COMPONENTS Quick)

add_executable(${APP_NAME}
    src/main.cpp
    src/filehelper.cpp
    src/filehelper.h
)

target_link_libraries(${APP_NAME} Qt5::Quick)

if(DEFINED CMAKE_INSTALL_PREFIX)
    set(DATA_DIR "${CMAKE_INSTALL_PREFIX}")
else()
    set(DATA_DIR ".")
endif()

install(TARGETS ${APP_NAME} DESTINATION ${DATA_DIR})
install(FILES ${MANIFEST_FILE} DESTINATION ${DATA_DIR})
install(FILES ${APPARMOR_FILE} DESTINATION ${DATA_DIR})
install(FILES ${DESKTOP_FILE} DESTINATION ${DATA_DIR})
install(FILES ${ICON_FILE} DESTINATION ${DATA_DIR})
install(DIRECTORY qml DESTINATION ${DATA_DIR})
