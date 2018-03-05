#
# Copyright 2018, Data61
# Commonwealth Scientific and Industrial Research Organisation (CSIRO)
# ABN 41 687 119 230.
#
# This software may be distributed and modified according to the terms of
# the BSD 2-Clause license. Note that NO WARRANTY is provided.
# See "LICENSE_BSD2.txt" for details.
#
# @TAG(DATA61_BSD)
#

cmake_minimum_required(VERSION 3.8.2)

/*# Ignore the following line. It is intended to apply to the output of this template. #*/
# THIS FILE IS AUTOMATICALLY GENERATED. YOUR EDITS WILL BE OVERWRITTEN.

# Include the CapDL tools build helpers, we will need this later one when generating capDL targets
include("${CAPDL_LOADER_BUILD_HELPERS}")

# Define names for tools we will use
set(OBJCOPY ${CROSS_COMPILER_PREFIX}objcopy)

# Declare our 'core' CAmkES libraries. These are the libraries that are considered minimal for the
# glue code that is linked to camkes applications to run
set(CAMKES_CORE_LIBS "sel4;muslc;sel4camkes;sel4sync;utils;sel4vka;sel4utils;sel4platsupport;platsupport;sel4vspace;sel4muslcsys")

# The main function generated by CAmkES does not conform to the standard main
# signatures, so disable warnings for this.
set(CAMKES_C_FLAGS "-Wno-main")

# We need to regenerate this file if any of the CAmkES descriptions change. To do this
# we define a custom command, who's output is this file, that does nothing and depends
# upon all our input files. This will cause ninja to believe that if any of those files
# change, then this generated file is out of date, and thus it needs to rerun cmake.
# The rerunning of cmake is what will then actually generate a new version of this file
#
# This is very much a convenience helper though and it is always more reliable to
# explicitly invoke 'cmake' manually instead of relying on this rule to cause ninja to rerun
add_custom_command(
    OUTPUT "${CMAKE_CURRENT_BINARY_DIR}/camkes-gen.cmake"
    COMMAND touch "${CMAKE_CURRENT_BINARY_DIR}/camkes-gen.cmake"
    DEPENDS /*? ' '.join(imported) ?*/
)
add_custom_target(camkes_gen_target DEPENDS "${CMAKE_CURRENT_BINARY_DIR}/camkes-gen.cmake")

/*- set instances = composition.instances -*/
/*- set connections = composition.connections -*/

/*# The terms 'group' and 'address space' are currently synonymous. We can
 *# derive the groups by collecting all the instances' address spaces.
  #*/
/*- set groups = set(map(lambda('x: x.address_space'), filter(lambda('x: not x.type.hardware'), instances))) -*/

# We build up a list of all the generated items that we want to construct a single
# camkes invocation
set(item_list "")
set(outfile_list "")
set(reflow_commands "")

macro(ParentListAppend list)
    set(local_list_value "${${list}}")
    list(APPEND local_list_value ${ARGN})
    set(${list} "${local_list_value}" PARENT_SCOPE)
endmacro(ParentListAppend list)

# Helper function for declaring a generated file
function(CAmkESAddGen output item)
    cmake_parse_arguments(PARSE_ARGV 2 CAMKES_GEN "SOURCE;C_STYLE;THY_STYLE" "" "")
    if (NOT "${CAMKES_GEN_UNPARSED_ARGUMENTS}" STREQUAL "")
        message(FATAL_ERROR "Unknown arguments to CAmkESGen: ${CAMKES_GEN_UNPARSED_ARGUMENTS}")
    endif()
    # generate command
    get_filename_component(out_dir "${output}" DIRECTORY)
    # Reflow generated files if requested
    if (CAMKES_GEN_C_STYLE AND (NOT ("${CAMKES_C_FMT_INVOCATION}" STREQUAL "")))
        ParentListAppend(reflow_commands sh -c
            "${CAMKES_C_FMT_INVOCATION} ${output} | ${CAMKES_SPONGE_INVOCATION} ${output}" "$<SEMICOLON>")
    elseif(CAMKES_GEN_THY_STYLE)
        ParentListAppend(reflow_commands sh -c
            "${TPP_TOOL} ${output} | ${CAMKES_SPONGE_INVOCATION} ${output}" "$<SEMICOLON>")
    endif()
    # Append the item and outfile
    ParentListAppend(item_list "${item}")
    ParentListAppend(outfile_list "${output}")
    # Add to the sources list if it's a source file
    if (CAMKES_GEN_SOURCE)
        ParentListAppend(gen_sources "${output}")
    endif()
    # Always add to the list of generated files
    ParentListAppend(gen_files "${output}")
endfunction(CAmkESAddGen)

function(CAmkESOutputGenCommand)
    if ("${item_list}" STREQUAL "")
        return()
    endif()
    set(reflow "${reflow_commands}")
    # If the reflow command was empty then we would output 'COMMAND ""' below, which
    # seems to be an error as it causes the cmake generation stage to occasionally segfault
    if ("${reflow}" STREQUAL "")
        set(reflow "true")
    endif()
    list(LENGTH outfile_list outfile_list_count)
    add_custom_command(
        OUTPUT ${outfile_list}
        COMMAND
            ${CMAKE_COMMAND} -E env ${CAMKES_TOOL_ENVIRONMENT} "${CAMKES_TOOL}"
                --file "${CAMKES_ADL_SOURCE}"
                "--item;$<JOIN:${item_list},;--item;>"
                "--outfile;$<JOIN:${outfile_list},;--outfile;>"
                ${CAMKES_FLAGS}
        COMMAND "${reflow}"
        DEPENDS
            ${CAMKES_ADL_SOURCE}
            /*? ' '.join(imported) ?*/
            # This pulls in miscelaneous dependencies such as the camkes-accelerator
            # which is used by the camkes tool
            ${CAMKES_TOOL_DEPENDENCIES}
        VERBATIM
        COMMAND_EXPAND_LISTS
        COMMENT "Performing CAmkES generation for ${outfile_list_count} files"
    )
    set(reflow_commands "" PARENT_SCOPE)
    set(item_list "" PARENT_SCOPE)
    set(outfile_list "" PARENT_SCOPE)
endfunction(CAmkESOutputGenCommand)

# We use a macro to control generating single or multiple outfiles from the CAmKES runner
# in order for the functions this calls to effectively run in the parent scope (as they
# need to modify global variables)
macro(CAmkESGen output item)
    CAmkESAddGen("${output}" "${item}" ${ARGN})
    # Neither the caches nor the accelerator understand multiple outfiles
    # if neither are in use then we can defer the gen command until later,
    # otherwise we process it right now
    if (CAmkESCompilationCache OR CAmkESAccelerator)
        CAmkESOutputGenCommand()
    endif()
endmacro(CAmkESGen)

# A target for each binary that we need to build
/*- for i in instances if not i.type.hardware -*/
    # Variable for collecting generated files
    set(gen_files "")
    set(gen_sources "")
    # Retrieve the static sources for the component
    set(static_sources "$<TARGET_PROPERTY:CAmkESComponent_/*? i.type.name ?*/,COMPONENT_SOURCES>")
    set(extra_c_flags "$<TARGET_PROPERTY:CAmkESComponent_/*? i.type.name ?*/,COMPONENT_C_FLAGS>")
    set(extra_ld_flags "$<TARGET_PROPERTY:CAmkESComponent_/*? i.type.name ?*/,COMPONENT_LD_FLAGS>")
    set(extra_libs "$<TARGET_PROPERTY:CAmkESComponent_/*? i.type.name ?*/,COMPONENT_LIBS>")
    # Retrieve the static headers for the component
    set(includes "$<TARGET_PROPERTY:CAmkESComponent_/*? i.type.name ?*/,COMPONENT_INCLUDES>")
    # Generate camkes header
    set(generated_dir "${CMAKE_CURRENT_BINARY_DIR}//*? i.name ?*/")
    CAmkESGen("${generated_dir}/include/camkes.h" "/*? i.name ?*//header" C_STYLE)
    # Generated different entry points for the instance
    CAmkESGen("${generated_dir}/camkes.c" /*? i.name ?*//source SOURCE C_STYLE)
    /*- if configuration[i.name].get('debug') -*/
        CAmkESGen("${generated_dir}/camkes.debug.c" /*? i.name ?*//debug SOURCE C_STYLE)
    /*- endif -*/
    /*- if configuration[i.name].get('simple') -*/
        CAmkESGen("${generated_dir}/camkes.simple.c" /*? i.name ?*//simple SOURCE C_STYLE)
    /*- endif -*/
    /*- if configuration[i.name].get('rump_config') -*/
        CAmkESGen("${generated_dir}/camkes.rumprun.c" /*? i.name ?*//rumprun SOURCE C_STYLE)
    /*- endif -*/
    # Generate connectors for this instance
    /*- for c in connections -*/
        /*- for id, e in enumerate(c.from_ends) -*/
            set(unique_name /*? e.interface.name ?*/_/*? c.type.name ?*/_/*? id ?*/)
            /*- if e.instance.name == i.name -*/
                CAmkESGen("${generated_dir}/${unique_name}.c" /*? c.name ?*//from/source//*? id ?*/ SOURCE C_STYLE)
                # Add a rule to generate the header if this connector has a header template
                /*- if lookup_template('%s/from/header' % c.name, c) is not none -*/
                    CAmkESGen("${generated_dir}/include/${unique_name}.h" /*? c.name ?*//from/header//*? id ?*/ C_STYLE)
                /*- endif -*/
            /*- endif -*/
        /*- endfor -*/
        /*- for id, e in enumerate(c.to_ends) -*/
            set(unique_name /*? e.interface.name ?*/_/*? c.type.name ?*/_/*? id ?*/)
            /*- if e.instance.name == i.name -*/
                CAmkESGen("${generated_dir}/${unique_name}.c" /*? c.name ?*//to/source//*? id ?*/ SOURCE C_STYLE)
                # Add a rule to generate the header if this connector has a header template
                /*- if lookup_template('%s/to/header' % c.name, c) is not none -*/
                    CAmkESGen("${generated_dir}/include/${unique_name}.h" /*? c.name ?*//to/header//*? id ?*/ C_STYLE)
                /*- endif -*/
            /*- endif -*/
        /*- endfor -*/
    /*- endfor -*/
    # Generate our linker script
    set(linker_file "${generated_dir}/linker.lds")
    CAmkESGen("${linker_file}" /*? i.name ?*//linker)
    # Create a target for all our generated files
    set(gen_target /*? i.name ?*/_generated)
    add_custom_target(${gen_target} DEPENDS ${gen_files})
    # Build the actual binary
    set(target /*? i.name ?*/.instance.bin)
    add_executable(${target} EXCLUDE_FROM_ALL
        ${static_sources}
        ${gen_sources}
    )
    target_include_directories(${target} PRIVATE ${includes} "${generated_dir}/include")
    # Depend upon core camkes libraries
    target_link_libraries(${target} ${CAMKES_CORE_LIBS})
    # Depend upon additional libraries
    target_link_libraries(${target} ${extra_libs})
    # Depend upon target that creates the generated source files
    add_dependencies(${target} ${gen_target} CAmkESComponent_/*? i.type.name ?*/)
    # Set our CAmkES specific additional link flags
    set_property(TARGET ${target} APPEND_STRING PROPERTY LINK_FLAGS
        " -static -nostdlib -u _camkes_start -e _camkes_start ")
    /*- for symbol in kept_symbols(i.name) -*/
        set_property(TARGET ${target} APPEND_STRING PROPERTY LINK_FLAGS " -u /*? symbol ?*/ ")
    /*- endfor -*/
    # Add extra flags specified by the user
    target_compile_options(${target} PRIVATE ${extra_c_flags} ${CAMKES_C_FLAGS})
    set_property(TARGET ${TARGET} APPEND_STRING PROPERTY LINK_FLAGS ${extra_ld_flags})
    # Only incrementally link if this instance is going on to become part of a
    # group.
    # TODO: we care about being grouped elsewhere as well. generalize this
    /*- set grouped = [False] -*/
    /*- for inst in instances if not i.type.hardware -*/
        /*- if id(i) != id(inst) and inst.address_space == i.address_space -*/
            /*- do grouped.__setitem__(0, True) -*/
        /*- endif -*/
    /*- endfor -*/
    /*- if grouped[0] -*/
        set_property(TARGET ${target} APPEND_STRING PROPERTY LINK_FLAGS " -Wl,--relocatable ")
    /*- endif -*/
    set_property(TARGET ${target} APPEND_STRING PROPERTY LINK_FLAGS " -Wl,--script=${linker_file} ")
/*- endfor -*/

# We need to apply objcopy to each component instance's ELF before we link them
# into a flattened binary in order to avoid symbol collision. Note that when we
# mangle symbols, we use the prefix 'camkes ' to avoid colliding with any
# user-provided symbols.
/*- set instancelist = set() -*/
/*- for i in instances if not i.type.hardware -*/
/*- set pre = NameMangling.Perspective(phase=NameMangling.TEMPLATES, instance=i.name, group=i.address_space) -*/
/*- set post = NameMangling.Perspective(phase=NameMangling.FILTERS, instance=i.name, group=i.address_space) -*/
    set(input_target /*? i.name ?*/.instance.bin)
    set(output ${CMAKE_CURRENT_BINARY_DIR}//*? i.name ?*/.instance-copy.bin)
    set(output_target /*? i.name ?*/_instance_copy_target)
    set(input $<TARGET_FILE:${input_target}>)
    add_custom_command(
        OUTPUT "${output}"
        COMMAND
        # Brace yourself. This is going to be a bumpy ride.
        ${OBJCOPY}
            /*# Use a dummy impossible symbol of the empty string here, because
             *# marking one symbol as 'keep global' causes all others to be demoted
             *# to local. This allows us to avoid symbol collisions from
             *# user-provided symbols.
              #*/
            --keep-global-symbol ""

            /*# Rename the entry point to avoid symbol conflicts when we are
             *# colocated with other components. Note that we will still use this as
             *# the entry point.
              #*/
            --redefine-sym "_camkes_start=/*? post['entry_symbol'] ?*/"

            /*# Rename the DMA pools so they don't collide. #*/
            --redefine-sym "/*? pre['dma_pool_symbol'] ?*/=/*? post['dma_pool_symbol'] ?*/"

            /*# Rename shared memory symbols so they don't collide. While doing so,
             *# we update their information in the shared memory metadata so they
             *# can still be located by the CapDL filters.
              #*/
            /*- for mappings in shmem.values() -*/
                /*- set new_mappings = [] -*/
                /*- for local in mappings[i.name] -*/
                    /*- set old_name = local[0] -*/
                    /*- set new_name = 'camkes shmem %s %s' % (i.name, local[0]) -*/
                    --redefine-sym "/*? old_name ?*/=/*? new_name ?*/"
                    /*- do new_mappings.append((new_name, local[1], local[2])) -*/
                /*- endfor -*/
                /*- do mappings.__setitem__(i.name, new_mappings) -*/
            /*- endfor -*/
            /*- for c in connections -*/
                /*- if c.type.name == 'seL4DirectCall' -*/
                    /*# For all 'from' connection ends (calls to unresolved symbols),
                     *# rename the symbols so they will correctly link to the
                     *# implementations provided by the 'to' side.
                      #*/
                    /*- for e in c.from_ends -*/
                        /*- if id(e.instance) == id(i) -*/
                            /*- for m in e.interface.type.methods -*/
                                --redefine-sym "/*? e.interface.name ?*/_/*? m.name ?*/=camkes connection /*? e.parent.name ?*/_/*? m.name ?*/"
                            /*- endfor -*/
                        /*- endif -*/
                    /*- endfor -*/
                    /*# For all 'to' connection ends (implementations of procedures),
                     *# rename the symbols so they will be found during the next
                     *# linking stage. Note we need to mark them as 'keep global' or
                     *# they will not be visible during the next link.
                      #*/
                    /*- for e in c.to_ends -*/
                        /*- if id(e.instance) == id(i) -*/
                            /*- if '%s_%s' % (i.name, e.interface.name) in instancelist -*/
                                /*- continue -*/
                            /*- endif -*/
                            /*- do instancelist.add('%s_%s' % (i.name, e.interface.name)) -*/
                            /*- for m in e.interface.type.methods -*/
                                --redefine-sym "/*? e.interface.name ?*/_/*? m.name ?*/=camkes connection /*? e.parent.name ?*/_/*? m.name ?*/"
                                --keep-global-symbol "camkes connection /*? e.parent.name ?*/_/*? m.name ?*/"
                            /*- endfor -*/
                        /*- endif -*/
                    /*- endfor -*/
                /*- endif -*/
            /*- endfor -*/
            "${input}" "${output}"
        COMMAND
            # Some toolchains insert exception handling infrastructure whether we ask
            # for it or not. The preceding `objcopy` step breaks references in
            # implicit `.eh_frame`s and friends, which then goes on to cause a linker
            # warning. Rather than attempt some complicated gymnastics to repair these
            # references, we just strip the exception handling pieces. To further
            # complicate the process, some architectures require an `.eh_frame` and
            # attempting to remove it causes errors. To handle this we just blindly
            # try to remove it and mask errors. We can't do this unconditionally in
            # the preceding `objcopy` because it fails when our toolchain has *not*
            # inserted exception handling pieces or when we're targeting an
            # architecture that requires `.eh_frame`.
            bash -c "${OBJCOPY} --remove-section .eh_frame --remove-section .eh_frame_hdr \
                --remove-section .rel.eh_frame --remove-section .rela.eh_frame ${output} \
                >/dev/null 2>/dev/null"
        VERBATIM
        DEPENDS ${input_target}
    )
    add_custom_target(/*? i.name ?*/_instance_copy_target DEPENDS "${output}")
    # TODO target for dependencies
/*- endfor -*/

# Define the linker we used for instances groups. This is just C linking but without crt objects
# or any other libraries, we just want the flags to generate the correct binary type
set(CMAKE_INSTANCE_GROUP_LINK_EXECUTABLE "<CMAKE_C_COMPILER> <FLAGS> <CMAKE_C_LINK_FLAGS> <LINK_FLAGS> <OBJECTS> -o <TARGET>" CACHE INTERNAL "" FORCE)
# Finally link together the instances in the different groups */
/*- for g in groups -*/
    /*- set p = Perspective(group=g) -*/
    # Find all the instances that are part of this group */
    set(instances "")
    set(instance_targets "")
    /*- for i in instances if not i.type.hardware -*/
        /*- set q = Perspective(group=i.address_space) -*/
        /*- if p['elf_name'] == q['elf_name'] -*/
            list(APPEND instances "/*? i.name ?*/.instance-copy.bin")
            list(APPEND instance_targets "/*? i.name ?*/_instance_copy_target")
            # Define the copies as objects in case we need to link them into a group and
            # we would like cmake to not attempt to compile them
            set_property(SOURCE "/*? i.name ?*/.instance-copy.bin" PROPERTY EXTERNAL_OBJECT TRUE)
        /*- endif -*/
    /*- endfor -*/
    set(target ${CMAKE_CURRENT_BINARY_DIR}//*? p['elf_name'] ?*/)
    list(LENGTH instances instances_len)
    if (${instances_len} GREATER 1)
        add_executable(/*? p['elf_name'] ?*/ EXCLUDE_FROM_ALL ${instances})
        add_dependencies(/*? p['elf_name'] ?*/ ${instance_targets})
        # Use a custom linker definition that will not include crt objects
        set_property(TARGET /*? p['elf_name'] ?*/ PROPERTY LINKER_LANGUAGE INSTANCE_GROUP)
        # Note that we deliberately give groups a
        # broken entry point so that, if they are incorrectly loaded without correct
        # initial instruction pointers, threads will immediately fault
        set_property(TARGET /*? p['elf_name'] ?*/ APPEND PROPERTY LINK_FLAGS " -static -nostdlib --entry=0x0 -Wl,--build-id=none")
    else()
        add_custom_command(
            OUTPUT ${target}
            COMMAND
                cp "${instances}" "${target}"
            DEPENDS
                ${instances}
                ${instance_targets}
        )
    endif()
    add_custom_target(/*? p['elf_name'] ?*/_group_target DEPENDS "${target}")
/*- endfor -*/

# Generate our targets up to this point
CAmkESOutputGenCommand()

set(capdl_elf_depends "")
set(capdl_elf_targets "")
/*- for g in groups -*/
    /*- set p = Perspective(group=g) -*/
    list(APPEND capdl_elf_depends "${CMAKE_CURRENT_BINARY_DIR}//*? p['elf_name'] ?*/")
    list(APPEND capdl_elf_targets "/*? p['elf_name'] ?*/_group_target")
/*- endfor -*/
# CapDL generation. Aside from depending upon the CAmkES specifications themselves, it
# depends upon the copied instance binaries
# First define the capDL spec generation from CAmkES
add_custom_command(
    OUTPUT "${CAMKES_CDL_TARGET}"
    COMMAND
        ${CMAKE_COMMAND} -E env ${CAMKES_TOOL_ENVIRONMENT} "${CAMKES_TOOL}"
            /*- for g in groups -*/
                /*- set p = Perspective(group=g) -*/
                --elf ${CMAKE_CURRENT_BINARY_DIR}//*? p['elf_name'] ?*/
            /*- endfor -*/
            --file "${CAMKES_ADL_SOURCE}"
            --item capdl
            --outfile "${CAMKES_CDL_TARGET}"
            ${CAMKES_FLAGS}
    DEPENDS
        /*? ' '.join(imported) ?*/
        ${CAMKES_ADL_SOURCE}
        ${capdl_elf_depends}
        ${capdl_elf_targets}
        # This pulls in miscelaneous dependencies such as the camkes-accelerator
        # which is used by the camkes tool
        ${CAMKES_TOOL_DEPENDENCIES}
)
add_custom_target(camkes_capdl_target DEPENDS "${CAMKES_CDL_TARGET}")

# Invoke the parse-capDL tool to turn the CDL spec into a C spec
add_custom_command(
    OUTPUT "capdl_spec.c"
    COMMAND
        ${CAPDL_TOOL_PATH}/parse-capDL --code capdl_spec.c "${CAMKES_CDL_TARGET}"
    DEPENDS
        "${CAMKES_CDL_TARGET}"
        camkes_capdl_target
        parse_capdl_tool
)
add_custom_target(capdl_c_spec_target DEPENDS capdl_spec.c)

# Ask the CapDL tool to generate an image with our given copied/mangled instances
BuildCapDLApplication(
    C_SPEC "capdl_spec.c"
    /*- for g in groups -*/
        /*- set p = Perspective(group=g) -*/
        ELF "${CMAKE_CURRENT_BINARY_DIR}//*? p['elf_name'] ?*/"
    /*- endfor -*/
    DEPENDS
        # Dependency on the C_SPEC and ELFs are added automatically, we just have to add the target
        # depenencies
        capdl_c_spec_target
        ${capdl_elf_targets}
    OUTPUT "capdl-loader"
)
DeclareRootserver("capdl-loader")

# Ensure we generated all the files we intended to, this is just sanity checking
if (NOT ("${item_list}" STREQUAL ""))
    message(FATAL_ERROR "Items added through CAmkESGen not generated")
endif()
