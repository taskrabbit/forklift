# Change Log

## [2.0.0 - Unreleased]
### Major
- Remove support for Ruby 1.9.3 and earlier. This version is no longer
  supported per [this announcement](https://www.ruby-lang.org/en/news/2015/02/23/support-for-ruby-1-9-3-has-ended/).

### Added
- More docs around the Mysql code.
- New maintainer contact information added to gem

### Fixed
- Gem spec license was incorrectly referring to MIT while the license is
  Apache-2.0

### Changed
- Transitioned `Forklift::Patterns::Mysql` methods to use an options `Hash`
  instead of positional parameters.
- `Forklift::Patterns::Mysql.mysql_optimistic_import` no longer loops
  through all tables. This behavior was inconsitent with the semantics
  of similar methods and caused problems if the specific tables required
  different parameters to be imported properly
