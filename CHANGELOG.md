# Changelog

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
