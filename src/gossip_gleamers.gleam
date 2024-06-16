import gleam/dynamic.{field, int, list, string}
import gleam/erlang
import gleam/int
import gleam/io
import gleam/json
import gleam/option.{type Option, None, Some}
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

type Request {
  InitReq(msg_id: Int, node_id: String, node_ids: List(String))
  EchoReq(msg_id: Int, content: String)
  IdReq(msg_id: Int)
}

type Response {
  InitRsp(in_reply_to: Int)
  EchoRsp(msg_id: Int, in_reply_to: Int, content: String)
  IdRsp(in_reply_to: Int, id: Int)
  ErrorMsg(in_reply_to: Int, code: Int, text: String)
}

fn body_from_json(dict: dynamic.Dynamic) {
  use t <- result.try(field(named: "type", of: string)(dict))
  io.debug(t)
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
    "generate" -> {
      // {
      //   "type": "generate",
      //   "msg_id": 1
      // }
      let id_decoder = dynamic.decode1(IdReq, field(named: "msg_id", of: int))
      id_decoder(dict)
    }
    t -> panic as { "unknown message type " <> t }
  }
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
    IdRsp(in_reply_to, id) -> {
      json.object([
        #("type", json.string("generate_ok")),
        #("in_reply_to", json.int(in_reply_to)),
        #("id", json.int(id)),
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

type State {
  State(node_id: Option(Int), sequence_no: Int, ots: Int)
}

fn loop(state: State) {
  let input = result.unwrap(erlang.get_line(""), "")
  use msg <- result.try(msg_from_json(input))
  // io.debug(msg)
  let #(_, s, us) = erlang.erlang_timestamp()
  let ms = s * 1000 + us / 1000
  let #(state, reply) = case msg {
    Message(a, b, InitReq(msg_id, node_id, _node_ids)) -> {
      // io.println_error("InitReq")
      let node_id = string.drop_left(node_id, 1)
      io.debug(node_id)
      let id = result.unwrap(int.parse(node_id), -1)
      #(State(Some(id), state.sequence_no, ms), Message(b, a, InitRsp(msg_id)))
    }
    Message(a, b, EchoReq(msg_id, content)) -> {
      // io.println_error("EchoReq")
      // io.println_error(content)
      #(
        State(state.node_id, state.sequence_no, ms),
        Message(b, a, EchoRsp(msg_id, 1, content)),
      )
    }
    Message(a, b, IdReq(msg_id)) -> {
      // | timestamp | node id | sequence no. |
      // | 17        | 6       | 8            |
      // total 31
      let State(node_id, sequence_no, ts) = state
      case node_id {
        None -> {
          let error_msg = Message(b, a, ErrorMsg(msg_id, 1, "node id not set"))
          #(state, error_msg)
        }
        Some(id) -> {
          let sequence_no = case ts >= ms {
            True -> sequence_no
            False -> 0
          }
          io.debug(#(ts, ms, sequence_no))
          let ms = int.max(ts, ms)
          let uid =
            ms
            |> int.bitwise_and(0x1FFFF)
            |> int.bitwise_shift_left(6)
            |> int.bitwise_or(id)
            |> int.bitwise_shift_left(8)
            |> int.bitwise_or(sequence_no)
          #(
            State(state.node_id, sequence_no + 1, ms),
            Message(b, a, IdRsp(msg_id, uid)),
          )
        }
      }
    }
  }
  // io.debug(reply)
  msg_to_json(reply)
  |> json.to_string
  |> io.println
  loop(state)
}

pub fn main() {
  let #(_, s, us) = erlang.erlang_timestamp()
  let ms = s * 1000 + us / 1000
  loop(State(None, 0, ms))
}
