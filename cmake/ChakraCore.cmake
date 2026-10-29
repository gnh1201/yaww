if(NOT WIN32 OR NOT MSVC)
	message(FATAL_ERROR "WEBVIEW_ENABLE_CHAKRACORE currently requires Windows and MSVC")
endif()

include(FetchContent)

FetchContent_Declare(chakracore
	GIT_REPOSITORY https://github.com/chakra-core/ChakraCore.git
	GIT_TAG master
	GIT_SHALLOW TRUE
	UPDATE_DISCONNECTED FALSE
)
FetchContent_GetProperties(chakracore)
if(NOT chakracore_POPULATED)
	FetchContent_Populate(chakracore)
endif()

if(CMAKE_GENERATOR_PLATFORM MATCHES "^[Aa][Rr][Mm]64")
	message(FATAL_ERROR "The current ChakraCore Visual Studio solution integration supports x86/x64 only.")
elseif(CMAKE_SIZEOF_VOID_P EQUAL 8)
	set(CHAKRACORE_PLATFORM x64)
else()
	set(CHAKRACORE_PLATFORM x86)
endif()

set(CHAKRACORE_OUTPUT_DIR
	"${chakracore_SOURCE_DIR}/Build/VcBuild/bin/${CHAKRACORE_PLATFORM}_release")
if(WEBVIEW_CHAKRACORE_USE_PREBUILT)
	if(WEBVIEW_CHAKRACORE_PREBUILT_DIR)
		set(CHAKRACORE_OUTPUT_DIR "${WEBVIEW_CHAKRACORE_PREBUILT_DIR}")
	else()
		if(CHAKRACORE_PLATFORM STREQUAL "x64")
			set(CHAKRACORE_PREBUILT_SHA256
				"7D71EA596F3E69073BA0D39B8625CDD82B67DBD14744F43A9F568CE50EF5470E")
		else()
			set(CHAKRACORE_PREBUILT_SHA256
				"FC654B3632B9CE7D673A6040B31355C536B91881C17ACDDBABFA94763CDC7149")
		endif()
		string(REGEX REPLACE "/+$" "" CHAKRACORE_PREBUILT_URL
			"${WEBVIEW_CHAKRACORE_PREBUILT_URL}")
		FetchContent_Declare(chakracore_prebuilt
			URL "${CHAKRACORE_PREBUILT_URL}/${CHAKRACORE_PLATFORM}_release.zip"
			URL_HASH "SHA256=${CHAKRACORE_PREBUILT_SHA256}")
		FetchContent_GetProperties(chakracore_prebuilt)
		if(NOT chakracore_prebuilt_POPULATED)
			FetchContent_Populate(chakracore_prebuilt)
		endif()
		set(CHAKRACORE_OUTPUT_DIR
			"${chakracore_prebuilt_SOURCE_DIR}/${CHAKRACORE_PLATFORM}_release")
	endif()
	foreach(CHAKRACORE_FILE ChakraCore.lib ChakraCore.dll)
		set(CHAKRACORE_BINARY
			"${CHAKRACORE_OUTPUT_DIR}/${CHAKRACORE_FILE}")
		if(NOT EXISTS "${CHAKRACORE_BINARY}")
			message(FATAL_ERROR
				"Prebuilt ChakraCore file not found: ${CHAKRACORE_BINARY}")
		endif()
		file(SIZE "${CHAKRACORE_BINARY}" CHAKRACORE_BINARY_SIZE)
		if(CHAKRACORE_BINARY_SIZE EQUAL 0)
			message(FATAL_ERROR "Prebuilt ChakraCore file is empty: ${CHAKRACORE_BINARY}")
		endif()
	endforeach()
	add_custom_target(webview_chakracore_build)
	message(STATUS "Using prebuilt ChakraCore for ${CHAKRACORE_PLATFORM}")
else()
	find_program(WEBVIEW_MSBUILD_EXECUTABLE NAMES MSBuild.exe msbuild REQUIRED)
	add_custom_target(webview_chakracore_build
		COMMAND "${WEBVIEW_MSBUILD_EXECUTABLE}"
			"${chakracore_SOURCE_DIR}/Build/Chakra.Core.sln"
			/m /p:Configuration=Release /p:Platform=${CHAKRACORE_PLATFORM}
		BYPRODUCTS
			"${CHAKRACORE_OUTPUT_DIR}/ChakraCore.lib"
			"${CHAKRACORE_OUTPUT_DIR}/ChakraCore.dll"
		COMMENT "Building latest ChakraCore master for ${CHAKRACORE_PLATFORM}"
		VERBATIM)
endif()

set(CHAKRACORE_LIBRARY "${CHAKRACORE_OUTPUT_DIR}/ChakraCore.lib")
set(CHAKRACORE_DLL "${CHAKRACORE_OUTPUT_DIR}/ChakraCore.dll")
set_property(TARGET webview PROPERTY WEBVIEW_CHAKRACORE_DLL
	"${CHAKRACORE_DLL}")

target_include_directories(webview SYSTEM INTERFACE "${chakracore_SOURCE_DIR}/lib/Jsrt")
target_compile_definitions(webview INTERFACE WEBVIEW_ENABLE_CHAKRACORE)
target_link_libraries(webview INTERFACE "${CHAKRACORE_LIBRARY}" shell32)
add_dependencies(webview webview_chakracore_build)

if(WEBVIEW_ENABLE_SCINTILLA_CONSOLE)
	include("${CMAKE_CURRENT_LIST_DIR}/Scintilla.cmake")
	target_compile_definitions(webview INTERFACE WEBVIEW_CHAKRACORE_SCINTILLA)
endif()

function(webview_deploy_chakracore target)
	get_property(chakracore_runtime TARGET webview
		PROPERTY WEBVIEW_CHAKRACORE_DLL)
	add_custom_command(TARGET "${target}" POST_BUILD
		COMMAND ${CMAKE_COMMAND} -E copy_if_different
			"${chakracore_runtime}" "$<TARGET_FILE_DIR:${target}>/ChakraCore.dll"
		VERBATIM)
	if(WEBVIEW_ENABLE_SCINTILLA_CONSOLE)
		get_property(scintilla_runtime TARGET webview
			PROPERTY WEBVIEW_SCINTILLA_DLL)
		get_property(lexilla_runtime TARGET webview
			PROPERTY WEBVIEW_LEXILLA_DLL)
		get_property(scintilla_license TARGET webview
			PROPERTY WEBVIEW_SCINTILLA_LICENSE)
		get_property(lexilla_license TARGET webview
			PROPERTY WEBVIEW_LEXILLA_LICENSE)
		add_custom_command(TARGET "${target}" POST_BUILD
			COMMAND ${CMAKE_COMMAND} -E copy_if_different
				"${scintilla_runtime}" "$<TARGET_FILE_DIR:${target}>/Scintilla.dll"
			COMMAND ${CMAKE_COMMAND} -E copy_if_different
				"${lexilla_runtime}" "$<TARGET_FILE_DIR:${target}>/lexilla.dll"
			COMMAND ${CMAKE_COMMAND} -E copy_if_different
				"${scintilla_license}"
				"$<TARGET_FILE_DIR:${target}>/Scintilla-LICENSE.txt"
			COMMAND ${CMAKE_COMMAND} -E copy_if_different
				"${lexilla_license}"
				"$<TARGET_FILE_DIR:${target}>/Lexilla-LICENSE.txt"
			VERBATIM)
	endif()
endfunction()
