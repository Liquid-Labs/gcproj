const shell = require('shelljs')

const execOpts = {
  shell: shell.which('bash'),
  silent: true,
}

export const LIQ = `${shell.pwd()}/dist/liq.sh`

export const selfOriginUrl = 'https://github.com/Liquid-Labs/liq-cli.git'

export const expectedCommandGroupUsage = (group) => new RegExp(`liq .*${group}.* <action>:`)

// I'd likue to do this, but it gives weird results on Mac Mojave const tmpDir = shell.tempdir(). Maybe it's OK, but let's be conservative till we confirm.
const tmpDir = `/tmp`

const allSuffix = Math.floor((1 + Math.random()) * 0x1000000000000)
  .toString(16)
  .substring(1)
export const localReposDir = `${tmpDir}/liq-local-repos-${allSuffix}`
export const localRepo = `${localReposDir}/lc-entities-model`
export const localRepoUrl = `file://${localRepo}`

export const setupLocalRepos = () => {
  let result = shell.mkdir('-p', localReposDir)
  expect(result.code).toEqual(0)
  result = shell.exec(`cd ${localReposDir} && git clone https://github.com/Liquid-Labs/lc-entities-model`, execOpts)
  expect(result.code).toEqual(0)
}

export const cleanupLocalRepos = () => {
  shell.rm('-rf', localReposDir)
}

export const setup = () => {
  const setupSuffix = Math.floor((1 + Math.random()) * 0x1000000000000)
    .toString(16)
    .substring(1)

  const home = `${tmpDir}/liq-cli-test-${setupSuffix}`
  const playground = `${home}/playground`
  // only valid if 'localCheckout' is called
  const localRepoCheckout = `${playground}/liquid_labs/@liquid-labs/lc-entities-model`
  // const testOriginDir = `${home}/git-origin`
  // const testCheckoutDir = `${playground}/test-checkout`

  const metaInit = () => {
    const result = shell.exec(`HOME=${home} ${LIQ} meta init -s -p ${playground} --org='git@github.com:Liquid-Labs'`, execOpts)
    expect(result.stderr).toEqual('')
    expect(result.code).toEqual(0)
  }

  const localCheckout = () => {
    const result = shell.exec(`HOME=${home} ${LIQ} projects import --no-fork ${localRepoUrl}`, execOpts)
    expect(result.stderr).toEqual('')
    expect(result.code).toEqual(0)
  }

  shell.mkdir('-p', home)

  return {
    home,
    playground,
    localRepoCheckout,
    // testOriginDir,
    // testCheckoutDir,
    metaInit,
    localCheckout,
    // TODO: don't cleanup if errors? (and mention the fact)
    cleanup: () => shell.rm('-rf', home)
  }
}
