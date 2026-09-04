//// A single-slot cache with a TTL, and — the part that matters when the
//// upstream is a PHP 5.3 server we do not control — a last-good value that
//// outlives its TTL and is served when a refresh fails.

import gleam/erlang/process.{type Subject}
import gleam/option.{type Option, None, Some}
import gleam/otp/actor
import gleam/result

pub type Entry(value) {
  Entry(value: value, fetched_at: Int)
}

pub opaque type Message(value) {
  Read(reply: Subject(Option(Entry(value))))
  Write(Entry(value))
}

pub type Cache(value) =
  Subject(Message(value))

pub fn start() -> Result(Cache(value), actor.StartError) {
  actor.new(None)
  |> actor.on_message(handle)
  |> actor.start
  |> result.map(fn(started) { started.data })
}

fn handle(
  state: Option(Entry(value)),
  message: Message(value),
) -> actor.Next(Option(Entry(value)), Message(value)) {
  case message {
    Read(reply) -> {
      process.send(reply, state)
      actor.continue(state)
    }
    Write(entry) -> actor.continue(Some(entry))
  }
}

pub fn read(cache: Cache(value)) -> Option(Entry(value)) {
  actor.call(cache, 1000, Read)
}

pub fn write(cache: Cache(value), value: value, now: Int) -> Nil {
  process.send(cache, Write(Entry(value, now)))
}
