import gleam/dynamic.{field, int, list, string}
import gleam/erlang
import gleam/int
import gleam/io
import gleam/json
import gleam/result
import gleam/string

type Maelstrom(body) {
  Message(src: String, dest: String, body: body)
}

fn msg_from_json(json_string: String) {
  let msg_decoder =
    dynamic.decode3(
      Message,
      field(named: "src", of: string),
      field(named: "dest", of: string),
      field(named: "body", of: body_from_json),
    )
  json.decode(from: json_string, using: msg_decoder)
}

type Body {
  InitReq(msg_id: Int, node_id: String, node_ids: List(String))
  EchoReq(msg_id: Int, content: String)
}

type Response {
  InitRsp(in_reply_to: Int)
  ErrorMsg(in_reply_to: Int, code: Int, text: String)
  EchoRsp(msg_id: Int, in_reply_to: Int, content: String)
}

fn body_from_json(dict: dynamic.Dynamic) {
  use t <- result.try(field(named: "type", of: string)(dict))
  case t {
    "init" -> {
      // {"type":"init","node_id":"n0","node_ids":["n0"],"msg_id":1}
      let init_decoder =
        dynamic.decode3(
          InitReq,
          field(named: "msg_id", of: int),
          field(named: "node_id", of: string),
          field(named: "node_ids", of: list(string)),
        )
      init_decoder(dict)
    }
    "echo" -> {
      // {
      //   "type": "echo",
      //   "msg_id": 1,
      //   "echo": "Please echo 35"
      // }
      let echo_decoder =
        dynamic.decode2(
          EchoReq,
          field(named: "msg_id", of: int),
          field(named: "echo", of: string),
        )
      echo_decoder(dict)
    }
    _ -> panic as "unknown message type"
  }
}

type State {
  State(node_id: Int)
}

fn msg_to_json(msg: Maelstrom(Response)) {
  json.object([
    #("src", json.string(msg.src)),
    #("dest", json.string(msg.dest)),
    #("body", body_to_json(msg.body)),
  ])
}

fn body_to_json(body: Response) {
  case body {
    InitRsp(in_reply_to) -> {
      json.object([
        #("type", json.string("init_ok")),
        #("in_reply_to", json.int(in_reply_to)),
      ])
    }
    ErrorMsg(in_reply_to, code, text) -> {
      json.object([
        #("type", json.string("error")),
        #("in_reply_to", json.int(in_reply_to)),
        #("code", json.int(code)),
        #("text", json.string(text)),
      ])
    }
    EchoRsp(msg_id, in_reply_to, content) -> {
      json.object([
        #("type", json.string("echo_ok")),
        #("msg_id", json.int(msg_id)),
        #("in_reply_to", json.int(in_reply_to)),
        #("echo", json.string(content)),
      ])
    }
  }
}

fn loop(state: State) {
  let input = result.unwrap(erlang.get_line(""), "")
  use msg <- result.try(msg_from_json(input))
  // io.debug(msg)
  let #(state, reply) = case msg {
    Message(a, b, InitReq(msg_id, node_id, _node_ids)) -> {
      // io.println_error("InitReq")
      let node_id = string.drop_right(node_id, 1)
      let id = result.unwrap(int.parse(node_id), -1)
      #(State(id), Message(b, a, InitRsp(msg_id)))
    }
    Message(a, b, EchoReq(msg_id, content)) -> {
      // io.println_error("EchoReq")
      // io.println_error(content)
      #(state, Message(b, a, EchoRsp(msg_id, 1, content)))
    }
  }
  // io.debug(reply)
  msg_to_json(reply)
  |> json.to_string
  |> io.println
  loop(state)
}

pub fn main() {
  loop(State(-1))
}
