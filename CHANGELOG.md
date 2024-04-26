# Changelog

## [0.28.3](https://github.com/cbochs/grapple.nvim/compare/v0.28.2...v0.28.3) (2024-04-26)


### Bug Fixes

* allow paths with spaces in tags window ([7b53a86](https://github.com/cbochs/grapple.nvim/commit/7b53a86ba4e0cdb6a58ff38d9d0d2e9f802e1ff9))
* **docs:** s/uv_timer_t/uv.uv_timer_t/ ([22d0272](https://github.com/cbochs/grapple.nvim/commit/22d02729333069b37d28b64174e04719b15a9e8c))
* incorrect docs regarding scope loading ([bbcbf20](https://github.com/cbochs/grapple.nvim/commit/bbcbf20b20405565558423695832addd5fac418d))
* minor cache module improvements ([1686932](https://github.com/cbochs/grapple.nvim/commit/1686932ad964bf4965b02900072cda716b0aed19))
* remove unused "key" from excluded subcommands ([a370614](https://github.com/cbochs/grapple.nvim/commit/a3706147140bcac63311ab4cdf244e7f435bb9b5))
* remove vim.print in Grapple.prune ([5cc6023](https://github.com/cbochs/grapple.nvim/commit/5cc6023febab1aebe4c02fde427fe8c4e8ce7133))
* use provided app instead of global app in scope content ([494b186](https://github.com/cbochs/grapple.nvim/commit/494b1862a841117a968cc1e243e9033ea905b193))
* use provided app instead of global app in scope_manager ([e967778](https://github.com/cbochs/grapple.nvim/commit/e967778ca5fa92c771da2f3d367d9940745ead0f))

## [0.28.2](https://github.com/cbochs/grapple.nvim/compare/v0.28.1...v0.28.2) (2024-04-09)


### Bug Fixes

* **docs:** correct [@cast](https://github.com/cast) for direction ([306eb36](https://github.com/cbochs/grapple.nvim/commit/306eb36d0bbf9e1e13cb36785dd377c90b78df77))
* **docs:** resolve some linting errors ([fcca9e8](https://github.com/cbochs/grapple.nvim/commit/fcca9e8c2a0cc8eab75fd89f49642d38d17e72db))

## [0.28.1](https://github.com/cbochs/grapple.nvim/compare/v0.28.0...v0.28.1) (2024-04-05)


### Bug Fixes

* **docs:** incorrect information for grapple.scope_definition type ([d256401](https://github.com/cbochs/grapple.nvim/commit/d256401e6850c30db96385df39f87db345e9c044))
* send tag absolute path to command instead of short path ([34b8f47](https://github.com/cbochs/grapple.nvim/commit/34b8f4728294058e9fdad116fd21f72feb66ab73))

## [0.28.0](https://github.com/cbochs/grapple.nvim/compare/v0.27.1...v0.28.0) (2024-03-31)


### Features

* add Cache:is_open(id) + some luadocs cleanup ([eee8d92](https://github.com/cbochs/grapple.nvim/commit/eee8d92e22facc4583e1431fc9de51b678e70234))
* add global cache to App ([526cf25](https://github.com/cbochs/grapple.nvim/commit/526cf25f277340c85f1992dcdfa12557fb4307c2))
* emit event on scope change "GrappleScopeChanged" (See [#147](https://github.com/cbochs/grapple.nvim/issues/147)) ([1e7ffdd](https://github.com/cbochs/grapple.nvim/commit/1e7ffdd48ed7a0e0f135c9b9684f5b74c5fbc243))

## [0.27.1](https://github.com/cbochs/grapple.nvim/compare/v0.27.0...v0.27.1) (2024-03-27)


### Bug Fixes

* **ci:** update documentation link ([15d44ff](https://github.com/cbochs/grapple.nvim/commit/15d44fff935cdf402b76a0d3fab79f3883d14f2c))

## [0.27.0](https://github.com/cbochs/grapple.nvim/compare/v0.26.0...v0.27.0) (2024-03-27)


### Features

* add scope priority ([5e85367](https://github.com/cbochs/grapple.nvim/commit/5e853679a8f5412243f30e8a49d5670535fa251b))
* hide scopes in scopes window ([c9907ec](https://github.com/cbochs/grapple.nvim/commit/c9907ec0293297eecab2a52fd3b6dcae5159f88b))


### Bug Fixes

* always unset window ids on window close ([601a73a](https://github.com/cbochs/grapple.nvim/commit/601a73a9c07a6a8c3082673785af1d84c0a7d6da))
* deepcopy tags before returning in Grapple.tags ([5d96868](https://github.com/cbochs/grapple.nvim/commit/5d96868a6e9791b7a8ee51a9eef43fc408b9650e))
* escape container_id in Loaded Scopes window ([8903901](https://github.com/cbochs/grapple.nvim/commit/89039013f6092053f1a45dd1abbc946ffc3d9f80))

## [0.26.0](https://github.com/cbochs/grapple.nvim/compare/v0.25.0...v0.26.0) (2024-03-21)


### Features

* prune scope save files based on last modified time ([#143](https://github.com/cbochs/grapple.nvim/issues/143)) ([f440b0a](https://github.com/cbochs/grapple.nvim/commit/f440b0a79e4c3cfa7e74b9bb68ca4a01621ce230))
* unload scopes ([5b184b6](https://github.com/cbochs/grapple.nvim/commit/5b184b6eea00e6c1083e74b472440b9c79e850f8))


### Bug Fixes

* add missing keymap description + handle nil descriptions in help window ([2f1011b](https://github.com/cbochs/grapple.nvim/commit/2f1011bd573c9a240e3eaed2365a8a050bdaeb5f))
* don't eagerly load current scope on setup ([b2b0586](https://github.com/cbochs/grapple.nvim/commit/b2b058606ce2ef4c9cb2ca133bb649aca648ecd1))
* place cursor on "current" entry in ui ([5f7cbaa](https://github.com/cbochs/grapple.nvim/commit/5f7cbaa65d3656ea1d18ee6dbc1781c27761158f))
* reduce window flickering when toggling unloaded scopes ([b381b69](https://github.com/cbochs/grapple.nvim/commit/b381b690fc112acb7f89573e0052ffccb2818ab7))

## [0.25.0](https://github.com/cbochs/grapple.nvim/compare/v0.24.1...v0.25.0) (2024-03-21)


### Features

* toggle showing loaded and unloaded scopes in UI with '&lt;s-cr&gt;' ([03ffbb9](https://github.com/cbochs/grapple.nvim/commit/03ffbb907adffd4d95214265ac987e312946674e))


### Bug Fixes

* allow deletion of unloaded scopes ([9350912](https://github.com/cbochs/grapple.nvim/commit/9350912b46ce0c2fc0386c82f40d71f26e6d01be))
* don't close loaded scopes window when a scope is reset ([dcc5984](https://github.com/cbochs/grapple.nvim/commit/dcc598415ce24e5faaee232c5e6a792bda7c957c))

## [0.24.1](https://github.com/cbochs/grapple.nvim/compare/v0.24.0...v0.24.1) (2024-03-19)


### Bug Fixes

* remove extra space in help footer ([9fb7660](https://github.com/cbochs/grapple.nvim/commit/9fb766082ebb908a8d89448f6aa50a593145c6a4))

## [0.24.0](https://github.com/cbochs/grapple.nvim/compare/v0.23.0...v0.24.0) (2024-03-19)


### Features

* add "help" footer for nvim-0.10 ([2545605](https://github.com/cbochs/grapple.nvim/commit/254560564779096cf646f78e585e4fd982da3924))

## [0.23.0](https://github.com/cbochs/grapple.nvim/compare/v0.22.0...v0.23.0) (2024-03-18)


### Features

* add "?" to open the help window ([be3cff9](https://github.com/cbochs/grapple.nvim/commit/be3cff9d08bb426f0c6bcf300667851f1f9bff3b))
* allow window style to be passed as an argument ([7456b74](https://github.com/cbochs/grapple.nvim/commit/7456b74db6b9474b6b2bba6b755bcb10a45c6550))


### Bug Fixes

* help window should handle non-consecutive quick select mappings ([5720f81](https://github.com/cbochs/grapple.nvim/commit/5720f81718db14a831c8b4a822c24c70d0ef8795))

## [0.22.0](https://github.com/cbochs/grapple.nvim/compare/v0.21.0...v0.22.0) (2024-03-18)


### Features

* use quick_select for statusline ([#129](https://github.com/cbochs/grapple.nvim/issues/129)) ([9cb1749](https://github.com/cbochs/grapple.nvim/commit/9cb17495546f0f7839b16f4b1e0285d893232127))

## [0.21.0](https://github.com/cbochs/grapple.nvim/compare/v0.20.1...v0.21.0) (2024-03-18)


### Features

* configure default command ([#127](https://github.com/cbochs/grapple.nvim/issues/127)) ([7a0a727](https://github.com/cbochs/grapple.nvim/commit/7a0a7273002c6ad0c02185b7d2d0f414dfdb06ad))

## [0.20.1](https://github.com/cbochs/grapple.nvim/compare/v0.20.0...v0.20.1) (2024-03-17)


### Bug Fixes

* minimum column ([#125](https://github.com/cbochs/grapple.nvim/issues/125)) ([42a150d](https://github.com/cbochs/grapple.nvim/commit/42a150d0f4674010cf7bee95bdd1648da0b1142d))

## [0.20.0](https://github.com/cbochs/grapple.nvim/compare/v0.19.0...v0.20.0) (2024-03-16)


### Features

* configure default scopes ([#123](https://github.com/cbochs/grapple.nvim/issues/123)) ([f06f13a](https://github.com/cbochs/grapple.nvim/commit/f06f13acccca7e0433dc5a259a85e39376ed2d28))


### Bug Fixes

* don't break lualine if Grapple.tags returns an error ([7f6edfe](https://github.com/cbochs/grapple.nvim/commit/7f6edfefd80fb25cbe790be1fd77d2c72045ce36))

## [0.19.0](https://github.com/cbochs/grapple.nvim/compare/v0.18.1...v0.19.0) (2024-03-15)


### Features

* dedicated lualine component ([#120](https://github.com/cbochs/grapple.nvim/issues/120)) ([b07efce](https://github.com/cbochs/grapple.nvim/commit/b07efce782ed47a20f9272598bc5a37216f33b4a))


### Bug Fixes

* don't allow empty tag names ([79fef01](https://github.com/cbochs/grapple.nvim/commit/79fef012fc2129865ac6612537835cb322ca2c74))
* use App.update instead of Settings.update during Grapple.setup ([c2c6cbf](https://github.com/cbochs/grapple.nvim/commit/c2c6cbf160cbf54e11af29eee3319162910045b6))
* use correct starting cycle position when not on a tagged file ([e4d2031](https://github.com/cbochs/grapple.nvim/commit/e4d20319d34ff717cb2bbad4556454fd477476d3))

## [0.18.1](https://github.com/cbochs/grapple.nvim/compare/v0.18.0...v0.18.1) (2024-03-14)


### Bug Fixes

* use correct byte indexes for highlights in nvim 0.10 ([02bcc88](https://github.com/cbochs/grapple.nvim/commit/02bcc8845c1b78c2f22b52798806add4973fc67a))

## [0.18.0](https://github.com/cbochs/grapple.nvim/compare/v0.17.2...v0.18.0) (2024-03-11)


### Features

* add `Grapple.find` ([#114](https://github.com/cbochs/grapple.nvim/issues/114)) ([fbacb20](https://github.com/cbochs/grapple.nvim/commit/fbacb204370594a1bc9d28677c179928adb0d834))
* make quick select configurable ([#112](https://github.com/cbochs/grapple.nvim/issues/112)) ([e2e7fea](https://github.com/cbochs/grapple.nvim/commit/e2e7feab1285e04da42f1af7d04627b5f65d0624))


### Bug Fixes

* **docs:** update link to grapple.tag ([ce47f12](https://github.com/cbochs/grapple.nvim/commit/ce47f12e47c00dd633af1168d25365bd60cb7df3))

## [0.17.2](https://github.com/cbochs/grapple.nvim/compare/v0.17.1...v0.17.2) (2024-03-09)


### Bug Fixes

* **ci:** only publish docs when README.md changes ([3bcbd2a](https://github.com/cbochs/grapple.nvim/commit/3bcbd2ae5b0a14f74271a20ad809ea27a008313a))
* **ci:** typo in ci.yml ([2c2adc9](https://github.com/cbochs/grapple.nvim/commit/2c2adc9888cb5e3d00f6e5fd67a84479ab170f67))
* **style:** format telescope extension ([03030c4](https://github.com/cbochs/grapple.nvim/commit/03030c43567672b18dadc9c053a51060a043ed7d))
* **test:** replace vim.fs.joinpath in testing until nvim-0.10 is released ([582b2be](https://github.com/cbochs/grapple.nvim/commit/582b2beb68a115bf3609beb8456777e8f0f3303d))
