include(FetchContent)

FetchContent_Declare(scintilla
	URL https://catswords.blob.core.windows.net/welsonjs/packages/archive/scintilla568.tgz
	URL_HASH SHA256=CA7FDA23125289BBF473AFD6FCD4959F65E828BFF1A8AE60C603B34DFCB3A777
)
FetchContent_Declare(lexilla
	URL https://catswords.blob.core.windows.net/welsonjs/packages/archive/lexilla555.tgz
	URL_HASH SHA256=2A06AEEB5DA5876F00BCCD2E89E838546EBAEA40AF4F73364FB2557083AFEE43
)

FetchContent_GetProperties(scintilla)
if(NOT scintilla_POPULATED)
	FetchContent_Populate(scintilla)
endif()
FetchContent_GetProperties(lexilla)
if(NOT lexilla_POPULATED)
	FetchContent_Populate(lexilla)
endif()

# FetchContent extracts each official archive directly into its source
# directory; the archive does not add another "scintilla" or "lexilla"
# directory level.
set(WEBVIEW_SCINTILLA_SOURCE_DIR "${scintilla_SOURCE_DIR}")
set(WEBVIEW_LEXILLA_SOURCE_DIR "${lexilla_SOURCE_DIR}")
if(NOT EXISTS "${WEBVIEW_SCINTILLA_SOURCE_DIR}/win32/scintilla.mak" OR
	NOT EXISTS "${WEBVIEW_LEXILLA_SOURCE_DIR}/src/lexilla.mak")
	message(FATAL_ERROR "The downloaded Scintilla/Lexilla source layout is unexpected")
endif()

# Lexilla's NMake file expects Scintilla's headers in a peer directory.
file(MAKE_DIRECTORY "${WEBVIEW_LEXILLA_SOURCE_DIR}/../scintilla")
file(COPY "${WEBVIEW_SCINTILLA_SOURCE_DIR}/include"
	DESTINATION "${WEBVIEW_LEXILLA_SOURCE_DIR}/../scintilla")

get_filename_component(WEBVIEW_MSVC_COMPILER_DIR "${CMAKE_CXX_COMPILER}" DIRECTORY)
find_program(WEBVIEW_NMAKE_EXECUTABLE
	NAMES nmake.exe nmake
	HINTS "${WEBVIEW_MSVC_COMPILER_DIR}")
if(NOT WEBVIEW_NMAKE_EXECUTABLE)
	message(FATAL_ERROR
		"NMake was not found. Configure ChakraCore builds from a Visual Studio developer environment.")
endif()

set(WEBVIEW_SCINTILLA_DLL "${WEBVIEW_SCINTILLA_SOURCE_DIR}/bin/Scintilla.dll")
set(WEBVIEW_LEXILLA_DLL "${WEBVIEW_LEXILLA_SOURCE_DIR}/bin/lexilla.dll")
set(WEBVIEW_SCINTILLA_LICENSE "${WEBVIEW_SCINTILLA_SOURCE_DIR}/License.txt")
set(WEBVIEW_LEXILLA_LICENSE "${WEBVIEW_LEXILLA_SOURCE_DIR}/License.txt")
set_property(TARGET webview PROPERTY WEBVIEW_SCINTILLA_DLL "${WEBVIEW_SCINTILLA_DLL}")
set_property(TARGET webview PROPERTY WEBVIEW_LEXILLA_DLL "${WEBVIEW_LEXILLA_DLL}")
set_property(TARGET webview PROPERTY WEBVIEW_SCINTILLA_LICENSE
	"${WEBVIEW_SCINTILLA_LICENSE}")
set_property(TARGET webview PROPERTY WEBVIEW_LEXILLA_LICENSE
	"${WEBVIEW_LEXILLA_LICENSE}")

add_custom_target(webview_scintilla_build
	COMMAND "${WEBVIEW_NMAKE_EXECUTABLE}" /f scintilla.mak QUIET=1
	WORKING_DIRECTORY "${WEBVIEW_SCINTILLA_SOURCE_DIR}/win32"
	BYPRODUCTS "${WEBVIEW_SCINTILLA_DLL}"
	COMMENT "Building Scintilla 5.6.8"
	VERBATIM)
add_custom_target(webview_lexilla_build
	COMMAND "${WEBVIEW_NMAKE_EXECUTABLE}" /f lexilla.mak QUIET=1
	WORKING_DIRECTORY "${WEBVIEW_LEXILLA_SOURCE_DIR}/src"
	BYPRODUCTS "${WEBVIEW_LEXILLA_DLL}"
	COMMENT "Building Lexilla 5.5.5"
	VERBATIM)

target_include_directories(webview SYSTEM INTERFACE
	"${WEBVIEW_SCINTILLA_SOURCE_DIR}/include"
	"${WEBVIEW_LEXILLA_SOURCE_DIR}/include")
add_dependencies(webview webview_scintilla_build webview_lexilla_build)
