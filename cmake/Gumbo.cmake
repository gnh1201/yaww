include(FetchContent)
enable_language(C)

# Pin the Gumbo parser revision so every backend uses the same HTML parser.
FetchContent_Declare(gumbo_parser
  URL https://catswords.blob.core.windows.net/welsonjs/packages/archive/gumbo-parser-6b414b60f83dc5d89970bbbd01b8f77cf7036eda.tar.gz
  URL_HASH SHA256=7BB495EEDFF6EBDAB114816A7F38748BDD7BA09035DDDDB7D443A8A3E0EE3208
)
FetchContent_GetProperties(gumbo_parser)
if(NOT gumbo_parser_POPULATED)
  FetchContent_Populate(gumbo_parser)
endif()

set(WEBVIEW_GUMBO_SOURCES
  attribute.c char_ref.c char_ref_gperf.c error.c parser.c
  string_buffer.c string_piece.c tag.c tokenizer.c utf8.c util.c vector.c)
list(TRANSFORM WEBVIEW_GUMBO_SOURCES
  PREPEND "${gumbo_parser_SOURCE_DIR}/src/")

add_library(webview_gumbo STATIC ${WEBVIEW_GUMBO_SOURCES})
target_include_directories(webview_gumbo PUBLIC
  "${gumbo_parser_SOURCE_DIR}/src"
  "${gumbo_parser_SOURCE_DIR}/visualc/include")
