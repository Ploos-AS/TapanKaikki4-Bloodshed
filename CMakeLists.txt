cmake_minimum_required(VERSION 2.8.12.2)
project(tapankaikki)
set(PROJECT_VERSION 4.09)

option(TK4_AMIGA "Build Tapan Kaikki 4 for classic AmigaOS/m68k" OFF)

if(TK4_AMIGA)
	# The classic Amiga build is fully static, so the Windows DLL-style EXPORT
	# annotation has no meaning here. Define it to nothing for all sources.
	add_definitions(-DAMIGA -DDISABLE_GAMMA -DTK4_NO_NETWORK -DEXPORT=)
endif()

if(NOT MINGW)
	set(CMAKE_CXX_FLAGS "-std=c++11 ${CMAKE_CXX_FLAGS}")
else()
	# Workaround for http://stackoverflow.com/q/38538924/3425536
	set(CMAKE_CXX_FLAGS "-std=gnu++11 ${CMAKE_CXX_FLAGS}")
	# Add -mwindows to the linker flags to avoid opening a console window when the
	# program is started (see https://cygwin.com/ml/cygwin/2007-04/msg00027.html)
	set(CMAKE_EXE_LINKER_FLAGS -mwindows)
endif()

# dependencies ###########################################################################
find_package(SDL 1 REQUIRED)
find_package(SDL_image 1 REQUIRED)
find_package(SDL_mixer 1 REQUIRED)
if(NOT TK4_AMIGA)
	find_package(SDL_net 1 REQUIRED)
endif()
include_directories(
	${SDL_INCLUDE_DIR}
	${SDL_IMAGE_INCLUDE_DIRS}
	${SDL_MIXER_INCLUDE_DIRS})
if(NOT TK4_AMIGA)
	include_directories(${SDL_NET_INCLUDE_DIRS})
	include_directories(/usr/local/include) # Temporary workaround for 'X11/Xlib.h not found'
endif()
if(APPLE)
	add_definitions(-DDISABLE_GAMMA) # SDL_SetGamma causes segfaults occasionally
endif()


# On Windows native win32 api is used and therefore GTK+ is not needed.
# The classic Amiga port intentionally excludes the editor during bring-up.
if(NOT WIN32 AND NOT TK4_AMIGA)
	find_package(GTK2)
	include_directories(${GTK2_INCLUDE_DIRS})
endif()


# common #################################################################################
file(GLOB COMMON_SOURCES src/common/*.h src/common/*.cpp)
if(WIN32)
	add_library(tk4-common SHARED ${COMMON_SOURCES})
	# Export symbols, default behaviour is import
	target_compile_definitions(tk4-common PUBLIC -DCOMMON_EXPORTS)
else()
	add_library(tk4-common STATIC ${COMMON_SOURCES})
endif()
target_link_libraries(tk4-common ${SDL_LIBRARY} ${SDL_IMAGE_LIBRARIES})


# game ###################################################################################
file(GLOB GAME_SOURCES src/*.h src/*.cpp src/*.rc)
if(TK4_AMIGA)
	# M1 uses a deliberately offline network backend while the base game is
	# brought up. SDL_net will be qualified separately later.
	list(REMOVE_ITEM GAME_SOURCES ${CMAKE_SOURCE_DIR}/src/network.cpp)
	list(REMOVE_ITEM GAME_SOURCES ${CMAKE_SOURCE_DIR}/src/lists_win32.cpp)
elseif(WIN32)
	list(REMOVE_ITEM GAME_SOURCES ${CMAKE_SOURCE_DIR}/src/lists_unix.cpp)
	list(REMOVE_ITEM GAME_SOURCES ${CMAKE_SOURCE_DIR}/src/network_amiga.cpp)
else()
	list(REMOVE_ITEM GAME_SOURCES ${CMAKE_SOURCE_DIR}/src/lists_win32.cpp)
	list(REMOVE_ITEM GAME_SOURCES ${CMAKE_SOURCE_DIR}/src/network_amiga.cpp)
endif()
add_executable(tk4 ${GAME_SOURCES})
if(TK4_AMIGA)
	target_link_libraries(tk4 tk4-common ${SDL_LIBRARY} ${SDL_IMAGE_LIBRARIES} ${SDL_MIXER_LIBRARIES})
else()
	target_link_libraries(tk4 tk4-common ${SDL_LIBRARY} ${SDL_IMAGE_LIBRARIES} ${SDL_MIXER_LIBRARIES} ${SDL_NET_LIBRARIES})
endif()


# editor #################################################################################
if(NOT TK4_AMIGA)
	file(GLOB EDITOR_SOURCES src/Editor/*.h src/Editor/*.cpp src/Editor/*.rc)
	if(WIN32)
		list(REMOVE_ITEM EDITOR_SOURCES ${CMAKE_SOURCE_DIR}/src/Editor/EditorLevelIO_gtk.cpp)
	else()
		list(REMOVE_ITEM EDITOR_SOURCES ${CMAKE_SOURCE_DIR}/src/Editor/EditorLevelIO_win32.cpp)
	endif()
	add_executable(tk4-editor ${EDITOR_SOURCES})
	target_link_libraries(tk4-editor tk4-common ${SDL_LIBRARY} ${SDL_IMAGE_LIBRARIES} ${GTK2_LIBRARIES})
endif()


# efpconv ################################################################################
if(NOT TK4_AMIGA)
	file(GLOB EFPCONV_SOURCES src/efpconv/*.h src/efpconv/*.cpp)
	add_executable(efpconv ${EFPCONV_SOURCES})
	target_link_libraries(efpconv tk4-common ${SDL_LIBRARY} ${SDL_IMAGE_LIBRARIES})
endif()


# installation configuration #############################################################
if(UNIX AND NOT TK4_AMIGA)
	include(GNUInstallDirs)
	install(TARGETS tk4 tk4-editor efpconv DESTINATION ${CMAKE_INSTALL_BINDIR})
	install(DIRECTORY data/ DESTINATION ${CMAKE_INSTALL_DATADIR}/tk4)
	add_definitions(-DDATADIR=\"${CMAKE_INSTALL_FULL_DATADIR}/tk4\")
endif()
