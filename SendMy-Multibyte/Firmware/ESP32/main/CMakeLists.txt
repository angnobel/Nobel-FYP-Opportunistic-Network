idf_component_register(SRCS "openhaystack_main.c" "uECC.c"
                           
                    INCLUDE_DIRS ".")
component_compile_options(-Wno-error=format= -Wno-format)