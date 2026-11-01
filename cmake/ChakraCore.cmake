if(NOT WIN32 OR NOT MSVC)
	message(FATAL_ERROR "WEBVIEW_ENABLE_CHAKRACORE currently requires Windows and MSVC")
endif()

include(FetchContent)

if(CMAKE_GENERATOR_PLATFORM MATCHES "^[Aa][Rr][Mm]64")
	message(FATAL_ERROR "The current ChakraCore Visual Studio solution integration supports x86/x64 only.")
elseif(CMAKE_SIZEOF_VOID_P EQUAL 8)
	set(CHAKRACORE_PLATFORM x64)
else()
	set(CHAKRACORE_PLATFORM x86)
endif()

if(WEBVIEW_CHAKRACORE_USE_PREBUILT)
	# The prebuilt archives have no headers, so fetch only the public ones.
	set(CHAKRACORE_HEADERS_COMMIT "97e68c9174209413f621deb2f963941550ef6f22")
	set(CHAKRACORE_INCLUDE_DIR "${CMAKE_BINARY_DIR}/_deps/chakracore_headers")
	foreach(CHAKRACORE_HEADER IN ITEMS
			"ChakraCore.h|434B9C015763DA00F01FB7B0A44373FE2C3586780C362A7A6A698B036F60A40F"
			"ChakraCommon.h|A9DFA1C9DBF303D10D930BA7A52F90F55ABC0B64B70B0383781E943DBF513306"
			"ChakraCommonWindows.h|E90CB3464C79DF93FCFDF478A8ED70F441199E4027950F53C0CEAD69FA3B2984"
			"ChakraDebug.h|3F080C921A37EF4D730218B5E41D5C3FA8EDA963AEBF388FB690679CF5D8B70B"
			"ChakraCoreWindows.h|BDD8AF9EAD66B0BA7B828E13F02AB65B400835F731C744F50D1C8D85071C3F4D")
		string(REPLACE "|" ";" CHAKRACORE_HEADER_ENTRY "${CHAKRACORE_HEADER}")
		list(GET CHAKRACORE_HEADER_ENTRY 0 CHAKRACORE_HEADER_NAME)
		list(GET CHAKRACORE_HEADER_ENTRY 1 CHAKRACORE_HEADER_SHA256)
		file(DOWNLOAD
			"https://catswords.blob.core.windows.net/welsonjs/packages/source/ChakraCore/${CHAKRACORE_HEADERS_COMMIT}/lib/Jsrt/${CHAKRACORE_HEADER_NAME}"
			"${CHAKRACORE_INCLUDE_DIR}/${CHAKRACORE_HEADER_NAME}"
			EXPECTED_HASH "SHA256=${CHAKRACORE_HEADER_SHA256}"
			TLS_VERIFY ON)
	endforeach()

	if(WEBVIEW_CHAKRACORE_PREBUILT_DIR)
		set(CHAKRACORE_OUTPUT_DIR "${WEBVIEW_CHAKRACORE_PREBUILT_DIR}")
	else()
		if(CHAKRACORE_PLATFORM STREQUAL "x64")
			set(CHAKRACORE_PREBUILT_SHA256
				"ED3A5B85E6BB696F179539F808FE770CD4DDEB05575F7EEB5FB9728DA06280EC")
		else()
			set(CHAKRACORE_PREBUILT_SHA256
				"75E792889292B14744810A7C72991757DEA38D78135E14DEDE63A33C28D6236C")
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
		set(CHAKRACORE_OUTPUT_DIR "${chakracore_prebuilt_SOURCE_DIR}")
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
	set(CHAKRACORE_INCLUDE_DIR "${chakracore_SOURCE_DIR}/lib/Jsrt")
	set(CHAKRACORE_OUTPUT_DIR
		"${chakracore_SOURCE_DIR}/Build/VcBuild/bin/${CHAKRACORE_PLATFORM}_release")

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

target_include_directories(webview SYSTEM INTERFACE "${CHAKRACORE_INCLUDE_DIR}")
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
