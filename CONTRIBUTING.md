# How to Contribute

## Getting Started
* Fork the repository and clone it to your local machine.
* Install Ruby 2.1.5 (this should work on any 2.x version, but this is
                      the prefered local setup)
* From within the cloned forklift repository run `bundle install`
* Install MySQL and Elasticsearch
* You should be all set with a working dev environment.

## Running Tests
  To run this test suite, you will need access to both a MySQL and Elasticsearch database. Test configurations are saved in `/spec/config/connections`. They assume that you have MySQL listening on `127.0.0.1:3306` and can be accessed with a user named `root` and with no password. Elasticsearch is expected to be listening on `127.0.0.1:9200`.

The MySQL tests will create and auto-populate 4 databases:

* `forklift_test_destination`
* `forklift_test_source_a`
* `forklift_test_source_b`
* `forklift_test_working`

You can run the whole suite of tests by running `rake`.
