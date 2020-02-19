'use strict'

var Main = require('./Main.js')

function main() {
  /*
  Here we could add variables such as

  var baseUrl = process.env.BASE_URL;

  Node will replace `process.env.BASE_URL`
  with the string contents of the BASE_URL environment
  variable at bundle/build time.

  These variables can be supplied to the Main.main function,
  however, you will need to change the type to accept variables, by default it is an Effect.
  You will probably want to make it a function from String -> Effect ()
*/

  Main.main()
}
