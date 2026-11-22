//// Upstream documents kept by key (a club code, a match sheet), so a failed
//// refresh can serve the last good copy. Bounded: when full, a new key evicts
//// the entry fetched longest ago, since anyone can ask for any club.

import gleam/dict.{type Dict}
import gleam/erlang/process.{type Subject}
import gleam/int
import gleam/list
import gleam/option.{type Option}
import gleam/otp/actor
import gleam/result

pub type Entry(value) {
  Entry(value: value, fetched_at: Int)
}

type State(value) {
  State(capacity: Int, entries: Dict(String, Entry(value)))
}

pub opaque type Message(value) {
  Read(key: String, reply: Subject(Option(Entry(value))))
  Write(key: String, entry: Entry(value))
}

pub type Cache(value) =
  Subject(Message(value))

pub fn start(capacity: Int) -> Result(Cache(value), actor.StartError) {
  actor.new(State(capacity:, entries: dict.new()))
  |> actor.on_message(handle)
  |> actor.start
  |> result.map(fn(started) { started.data })
}

fn handle(
  state: State(value),
  message: Message(value),
) -> actor.Next(State(value), Message(value)) {
  case message {
    Read(key, reply) -> {
      process.send(reply, dict.get(state.entries, key) |> option.from_result)
      actor.continue(state)
    }
    Write(key, entry) -> {
      let room = case
        dict.has_key(state.entries, key)
        || dict.size(state.entries) < state.capacity
      {
        True -> state.entries
        False -> drop_oldest(state.entries)
      }
      actor.continue(State(..state, entries: dict.insert(room, key, entry)))
    }
  }
}

fn drop_oldest(
  entries: Dict(String, Entry(value)),
) -> Dict(String, Entry(value)) {
  let oldest =
    dict.to_list(entries)
    |> list.sort(fn(a, b) {
      let #(_, first) = a
      let #(_, second) = b
      int.compare(first.fetched_at, second.fetched_at)
    })
    |> list.first
  case oldest {
    Ok(#(key, _)) -> dict.delete(entries, key)
    Error(_) -> entries
  }
}

pub fn read(cache: Cache(value), key: String) -> Option(Entry(value)) {
  actor.call(cache, 1000, Read(key, _))
}

pub fn write(cache: Cache(value), key: String, value: value, now: Int) -> Nil {
  process.send(cache, Write(key, Entry(value, now)))
}
