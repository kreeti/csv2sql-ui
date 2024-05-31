

<p align="center">
  <img src="https://raw.githubusercontent.com/Arp-G/csv2sql/master/.github/images/csv2sql.png" alt="Csv2Sql image"/>
</p>
<h3 align="center"> <i>CSV2SQL-UI is a Frontend app for CSV2SQL </i> </h3>

## Table of Contents
1. [What is Csv2sql-UI ?](#what)
2. [Using the browser based interface](#dashboard)
	1. [Running from source](#sourceinstall)
3. [Supported data types](#support)
4. [Handling custom date/datetime formats](#datetime)
5. [Known issues, caveats and troubleshooting](#issues)
6. [Future plans](#future)


*Please have a quick look over the [Known issues, caveats and troubleshooting](#issues) section before using the app.*

<a name="what"></a>
## What is Csv2sql-UI?

Csv2sql-UI is a Frontend application for [CSV2SQL](https://github.com/kreeti/csv2sql), where csv2sql is a blazing fast fully automated tool to load huge [CSV](https://en.wikipedia.org/wiki/Comma-separated_values) files into a [RDBMS](https://en.wikipedia.org/wiki/Relational_database).

Csv2sql-UI can automatically...

* Read csv files and infer the database table structure
* Create the required tables in the database
* Insert all the csvs into the database
* Do a simple validation check to ensures that all the data as been imported correctly.

<a name="dashboard"></a>
## Use csv2sql from your browser

For ease of use csv2sql has browser interface which can be used to easily configure the tool and also provides an interface that shows what is the progress of the various running tasks, which files are currently being processed, the current cpu and memory usage, etc.

<p align="center">
  <img src="https://github.com/kreeti/csv2sql/assets/69915843/a657f0ba-6364-4658-b572-147f9b1d3700" alt="browser interface demo"/>
</p>

<a name="sourceinstall"></a>
## Running the app from source code

You must have elixir, node.js and mysql/postgresql installed in your system to run Csv2Sql.

To use the app just clone this repository 
1. cd assets and run `npm install`
2. then install dependencies by `mix deps.get`

Finally, start the application by ```mix phx.server```

This runs the phoenix server at [localhost:4000](localhost:4000) which provides a browser based interface to use the app.

Thats all !

<a name="support"></a>
## Supported data types

Csv2sql currently supports [MySql](https://www.mysql.com/) and [PostgreSQL](https://www.postgresql.org/) database.

Csv2Sql will map data in CSVs into one of the following data types:


|   Type   | mysql| postgres |
|----------|------|----------|
| date     |  For values matching pattern like YYYY-MM-DD or [custom patterns](#datetime)    |  NOT SUPPORTED, will map to VARCHAR|
| datetime |   For values matching pattern like YYYY-MM-DD hh:mm:ss or [custom patterns](#datetime)  , (WARNING: fractional seconds or timezone information will be lost if present)   |  NOT SUPPORTED, will map to VARCHAR|
| boolean  |   Maps values 0/1 or true/false to [BIT](https://dev.mysql.com/doc/refman/8.0/en/bit-type.html) type   |  	Maps values 0/1 or true/false to [BOOLEAN](https://www.postgresql.org/docs/9.5/datatype-boolean.html) type     |
| integer  |  	[INT](https://dev.mysql.com/doc/refman/8.0/en/integer-types.html)  |  	[INT](https://www.postgresql.org/docs/9.5/datatype-numeric.html#DATATYPE-INT)     |
| float    |  	 [DOUBLE](https://dev.mysql.com/doc/refman/8.0/en/floating-point-types.html) |  	  [NUMERIC(1000, 100)](https://www.postgresql.org/docs/9.5/datatype-numeric.html#DATATYPE-NUMERIC-DECIMAL)   |
| varchar  |  	VARCHAR  |  	VARCHAR     |
| text     |  	TEXT  |  	TEXT     |

All other types of data, will map to either VARCHAR or TEXT.

<a name="datetime"></a>
## Handling custom date/datetime formats

By default csv2sql will identify date or datetime of the following patterns `YYYY-MM-DD` and `YYYY-MM-DD hh:mm:ss` respectively.
If a csv file contains date or datetime in some other format then they will be imported as varchar by default however by specifying custom
patterns we can import such data of arbitrary formats as date or datetime.

csv2sql uses the [Timex](https://github.com/bitwalker/timex) library to parse date/datetime.
You can specify multiple custom patterns for date or datetime as a string having one or more patterns separated by `;`

When using the Web UI for csv2sql enter these pattern strings in the config page under "Custom date patterns" or "Custom datetime patterns".

The patterns should be compatible with Timex directives specified [here](https://hexdocs.pm/timex/Timex.Format.DateTime.Formatters.Default.html#module-list-of-all-directives).

(Custom patterns are only supported when using the web ui and are not available in the cli version of the application)

#### Good to know/Caveats

* Fractional seconds or timezone information is not handled when importing datetime data.
* When multiple custom patterns are specified for large csvs the import process might be slower due to the additional overhead of matching patterns.
* Always double check the patterns specified and verify imported date or datetime data

#### Examples

To parse datetime like `11/14/2021 3:43:28 PM` a pattern like `{0M}/{0D}/{YYYY} {h12}:{m}:{s} {AM}` can be specified

The custom pattern needed is like...

`{0M}/{0D}/{YYYY} {h12}:{m}:{s} {AM}`

Consider a CSV with date or datetime having multiple formats like...

|Example Date|Date Pattern|Example Datetime|Datetime Pattern|
|--|--|--|--|
|2021-11-14|{YYYY}-{0M}-{0D}|2021-11-14T15:43:28|{YYYY}-{0M}-{0D}T{0h24}:{m}:{s}|
|11-14-2021|{0M}-{0D}-{YYYY}|11-14-2021 15:43:28|{0M}-{0D}-{YYYY} {0h24}:{m}:{s}|
|11/14/2021|{0M}/{0D}/{YYYY}|11/14/2021 3:43:28 PM|{0M}/{0D}/{YYYY} {h12}:{m}:{s} {AM}|

The pattern strings to parse the above csv would look like...

For date
`{YYYY}-{0M}-{0D};{0M}-{0D}-{YYYY}`

For datetime
`{YYYY}-{0M}-{0D}T{0h24}:{m}:{s};{0M}-{0D}-{YYYY} {0h24}:{m}:{s};{0M}/{0D}/{YYYY} {h12}:{m}:{s} {AM}`


<a name="issues"></a>
## Known issues, caveats and troubleshooting:

* Timestamp columns will lose there fractional seconds data or time zone information when importing to mysql.

* When importing into a mysql/postgres database you must create the database manually before running the application, otherwise it will fail.

* Csvsql uses the csv file names as table names, make sure that the csv file names are valid table names.

* Make sure your csvs have correct encoding and valid column names to avoid errors.

* If you face database connection timeout errors try reducing the worker and db_worker count in the configurations or change the database timeout, pool size and other related database configurations.

* In case of errors, check your terminal for a clue, or create an issue.

<a name="future"></a>
## Future

* Support for windows os
* Work on known issues and better support for various data types
