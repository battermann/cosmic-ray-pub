'use strict'

const redis = require('redis')
const { promisify } = require('util')

exports.createClientImpl = function (host) {
  return function (port) {
    return function (db) {
      return function (onError, onSuccess) {
        const client = redis.createClient({
          host: host,
          port: port,
          db: db
        })
        client.on('error', function (err) { client.quit(); onError(err) })
        client.on('connect', function () { onSuccess(client) })
      }
    }
  }
}

exports.appendToEventsImpl = function (client, data) {
  console.log(data)
  return promisify(client.xadd).bind(client)('events', 'MAXLEN', '~', '1000', '*', 'data', data)
}

exports.quitClientImpl = function (client) {
  return client.quit()
}

exports.setIndexImpl = function (client, index) {
  return promisify(client.set).bind(client)('index', index)
}

exports.getIndexImpl = function (client) {
  return promisify(client.get).bind(client)('index')
}
