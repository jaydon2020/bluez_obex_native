#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
CODEGEN_BUILD_DIR="${ROOT_DIR}/build/codegen"

# Locate sdbus-c++-xml2cpp -- check known build-tree paths first, then PATH.
_find_xml2cpp() {
    local candidates=(
        "${ROOT_DIR}/build/tools/sdbus-c++-xml2cpp"
        "${CODEGEN_BUILD_DIR}/tools/sdbus-c++-xml2cpp"
        "${ROOT_DIR}/build-codegen/tools/sdbus-c++-xml2cpp"
        "${ROOT_DIR}/build/native/third_party/sdbus-cpp/tools/sdbus-c++-xml2cpp"
        "${ROOT_DIR}/cmake-build-debug/tools/sdbus-c++-xml2cpp"
        "${ROOT_DIR}/cmake-build-release/tools/sdbus-c++-xml2cpp"
    )
    for candidate in "${candidates[@]}"; do
        if [[ -x "${candidate}" ]]; then
            echo "${candidate}"
            return 0
        fi
    done
    if command -v sdbus-c++-xml2cpp &>/dev/null; then
        command -v sdbus-c++-xml2cpp
        return 0
    fi
    if [[ -d "${ROOT_DIR}/native/third_party/sdbus-cpp" ]]; then
        cmake -S "${ROOT_DIR}/native/third_party/sdbus-cpp" \
            -B "${CODEGEN_BUILD_DIR}" \
            -DSDBUSCPP_BUILD_CODEGEN=ON \
            -DSDBUSCPP_BUILD_TESTS=OFF \
            -DSDBUSCPP_BUILD_EXAMPLES=OFF \
            -DSDBUSCPP_BUILD_DOCS=OFF \
            -DSDBUSCPP_INSTALL=OFF \
            -DBUILD_SHARED_LIBS=OFF >&2
        cmake --build "${CODEGEN_BUILD_DIR}" --target sdbus-c++-xml2cpp >&2
        echo "${CODEGEN_BUILD_DIR}/tools/sdbus-c++-xml2cpp"
        return 0
    fi
    echo "ERROR: sdbus-c++-xml2cpp not found and native/third_party/sdbus-cpp is missing." >&2
    return 1
}

XML2CPP="$(_find_xml2cpp)"
echo "Using: ${XML2CPP}"

# Run from repo root so include guards use relative paths.
cd "${ROOT_DIR}"
mkdir -p native/generated

${XML2CPP} --verbose --proxy=native/generated/client1_proxy.h \
    interfaces/org.bluez.obex.Client1.xml

${XML2CPP} --verbose --proxy=native/generated/session1_proxy.h \
    interfaces/org.bluez.obex.Session1.xml

${XML2CPP} --verbose --proxy=native/generated/transfer1_proxy.h \
    interfaces/org.bluez.obex.Transfer1.xml

${XML2CPP} --verbose --proxy=native/generated/phonebook_access1_proxy.h \
    interfaces/org.bluez.obex.PhonebookAccess1.xml

${XML2CPP} --verbose --proxy=native/generated/message_access1_proxy.h \
    interfaces/org.bluez.obex.MessageAccess1.xml

${XML2CPP} --verbose --proxy=native/generated/message1_proxy.h \
    interfaces/org.bluez.obex.Message1.xml

echo "Proxy generation complete."
