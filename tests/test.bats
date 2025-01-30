setup() {
  set -eu -o pipefail
  export DIR="$( cd "$( dirname "$BATS_TEST_FILENAME" )" >/dev/null 2>&1 && pwd )/.."
  export TESTDIR=~/tmp/envsa-ddev-playwright
  mkdir -p ${TESTDIR}
  export PROJNAME=envsa-ddev-playwright
  export DDEV_NON_INTERACTIVE=true
  ddev delete -Oy "${PROJNAME}" >/dev/null 2>&1 || true
  cd "${TESTDIR}"
  mkdir -p web

  echo "# user is ${USER}" >&3
  echo "# testdir is ${TESTDIR}" >&3

  echo "# configuring project..." >&3
  ddev config --project-name="${PROJNAME}" --docroot=web --project-type=php --corepack-enable=true
  echo "# ddev start" >&3
  ddev start -y >/dev/null
}

health_checks() {
  # Do something useful here that verifies the add-on
  ddev exec "curl -s https://localhost:443/ | grep -q phpinfo"
}

teardown() {
  set -eu -o pipefail
  cd "${TESTDIR}" || ( printf "unable to cd to %s\n" "${TESTDIR}" && exit 1 )
  ddev delete -Oy "${PROJNAME}" >/dev/null 2>&1
  [ "${TESTDIR}" != "" ] && rm -rf "${TESTDIR}"
}

get_addon() {
  set -eu -o pipefail
  cd "${TESTDIR}"
  echo "# ddev add-on get ${DIR} with project ${PROJNAME} in ${TESTDIR} ($(pwd))" >&3
  ddev add-on get "${DIR}"
  assert [ -f .ddev/config.playwright.yaml ]
  assert [ -f .ddev/commands/host/install-playwright ]
  assert [ -f .ddev/commands/host/playwright-ui ]
  assert [ -f .ddev/web-build/.gitignore ]
  assert [ -f .ddev/web-build/disabled.Dockerfile.playwright ]
  assert [ -x .ddev/web-build/install-kasmvnc.sh ]
  assert [ -f .ddev/web-build/Dockerfile.task ]
  assert [ -x .ddev/web-build/install-task.sh ]
  assert [ -f .ddev/web-build/kasmvnc.yaml ]
  assert [ -f .ddev/web-build/xstartup ]
  mkdir test
}

verify_run_playwright() {
  cp -av "$DIR"/tests/testdata/web/* web/
  assert [ -f web/index.php ]
  ddev install-playwright

  ddev exec -- which task

  mkdir -p test/playwright/tests
  cp "$DIR"/tests/testdata/phpinfo.spec.ts test/playwright/tests/phpinfo.spec.ts
  health_checks

  # Verify kasmvnc is listening.
  curl -s https://"${PROJNAME}".ddev.site:8444/
  curl -s --user "$USER":secret https://"${PROJNAME}.ddev.site:8444/"
  ddev logs
  echo "#" curl -s --user "$USER":secret https://"${PROJNAME}.ddev.site:8444/" >&3
  curl -s --user "$USER":secret https://"${PROJNAME}.ddev.site:8444/" | grep -q KasmVNC

  # Verify that browsers have been downloaded.
  ddev exec -- ls \~/.cache/ms-playwright
  run ddev exec -- ls \~/.cache/ms-playwright \| wc -l \| sed \'s/ *//\'
  # Playwright currently supports 5 browsers.
  assert_output 5

  # Verify we can run an example test.
  ddev playwright test --reporter=line
}

# @test "install from directory" {
#   get_addon
#   cp -av "$DIR"/tests/testdata/playwright test/playwright
#   ddev exec -d /var/www/html/test/playwright pnpm i
#   verify_run_playwright
# }

# @test "install requires a playwright installation" {
#   set -eu -o pipefail
#   cd "${TESTDIR}"
#   echo "# ddev add-on get ${DIR} with project ${PROJNAME} in ${TESTDIR} ($(pwd))" >&3
#   ddev add-on get "${DIR}"
#   run ddev install-playwright
#   assert_failure
# }

#@test "install from release" {
#  set -eu -o pipefail
#  cd ${TESTDIR} || ( printf "unable to cd to ${TESTDIR}\n" && exit 1 )
#  echo "# ddev add-on get ddev/ddev-addon-template with project ${PROJNAME} in ${TESTDIR} ($(pwd))" >&3
#  ddev add-on get ddev/ddev-addon-template
#  ddev restart >/dev/null
#  health_checks
#}
#
#
