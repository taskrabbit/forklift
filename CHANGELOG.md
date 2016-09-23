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
- Transitioned `Forklift::Patterns::Mysql` methods to use an options
  `Hash` instead of positional parameters. See:
  - `.pipe`
  - `.incremental_pipe`
  - `.optimistic_pipe`
  - `.mysql_optimistic_import`
  - `.mysql_incremental_import`
  - `.mysql_import`
  - `.can_incremental_pipe?`
  - `.can_incremental_import?`
- `Forklift::Patterns::Mysql.mysql_optimistic_import` no longer loops
  through all tables. This behavior was inconsitent with the semantics
  of similar methods and caused problems if the specific tables required
  different parameters to be imported properly
- `Forklift::Connection::Mysql#max_timestamp` now accepts a symbol for
  the matcher and returns a `Time` object. If no timestamp is found
  either due to missing table, missing column, or empty table then the
  epoch is returned (`Time.at(0)`).
- `Forklift::Connection::Mysql#read_since` expects a `Time` object for
  the second "since" parameter in accordance with the change to
  `#max_timestamp`.
