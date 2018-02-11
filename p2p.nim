# Copyright 2017 Yoshihiro Tanaka
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at

  # http://www.apache.org/licenses/LICENSE-2.0

# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# Author: Yoshihiro Tanaka <contact@cordea.jp>
# date  : 2018-02-11

import asyncnet
import websocket
import asyncdispatch
import asynchttpserver

var clients {.threadvar.}: seq[AsyncSocket]

proc call(sock: AsyncSocket, index: int) {.async.} =
  await sock.sendText("hello from " & $index, false)
  while true:
    try:
      let f = await sock.readData(false)
      if f.opcode == Opcode.Text:
        echo f.data
        # waitFor sock.sendText("hello from " & $index, false)
    except:
      echo getCurrentExceptionMsg()
      # clients.delete(req.client)
      break

proc connect(address: string) {.async.} =
  let ws = await newAsyncWebsocket(address, Port 4000, "/?encoding=text", ssl = false)
  clients.add(ws.sock)
  asyncCheck call(ws.sock, clients.len)

proc initApi() {.async.} =
  proc cb(req: Request) {.async.} =
    case req.url.path
    of "/peer":
      if req.reqMethod == HttpPost:
        asyncCheck connect(req.body)
        await req.respond(Http200, "")
      else:
        await req.respond(Http400, "")
    else:
      await req.respond(Http400, "")
  let server = newAsyncHttpServer()
  asyncCheck server.serve(Port(8080), cb)

proc initWs() {.async.} =
  proc cb(req: Request) {.async.} =
    let (success, error) = await verifyWebsocketRequest(req)
    if success:
      clients.add(req.client)
      asyncCheck call(req.client, clients.len)
  clients = @[]
  let server = newAsyncHttpServer()
  asyncCheck server.serve(Port(4000), cb)

asyncCheck initApi()
asyncCheck initWs()

runForever()
