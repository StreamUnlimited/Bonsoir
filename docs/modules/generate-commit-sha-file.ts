import { execSync } from 'child_process'
import fs from 'fs'
import { createResolver, defineNuxtModule } from '@nuxt/kit'
import * as logger from '../utils/logger'

export interface ModuleOptions {
  fileName: string
}

const name = 'generate-commit-sha-file'
export default defineNuxtModule<ModuleOptions>({
  meta: {
    name,
    version: '0.0.1',
    configKey: 'commitShaFileGenerator',
    compatibility: { nuxt: '^3.0.0' }
  },
  defaults: {
    fileName: 'latest-commit.json'
  },
  setup: (options, nuxt) => {
    const resolver = createResolver(import.meta.url)
    const srcDir = nuxt.options.srcDir
    const long = execSync('git rev-parse HEAD', { cwd: srcDir }).toString().trim()
    const short = execSync('git rev-parse --short HEAD', { cwd: srcDir }).toString().trim()
    fs.writeFileSync(resolver.resolve(srcDir, 'content', options.fileName), JSON.stringify({ long, short }))
    logger.success(name, `Wrote latest info commit for ${long}.`)
  }
})
