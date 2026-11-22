import gleam/option.{None, Some}
import gleeunit/should
import volley/cache

pub fn read_returns_what_was_written_test() {
  let assert Ok(store) = cache.start(2)
  cache.write(store, "0941410", "ours", 100)

  cache.read(store, "0941410")
  |> should.equal(Some(cache.Entry("ours", 100)))
  cache.read(store, "0885362") |> should.equal(None)
}

pub fn a_new_key_evicts_the_oldest_when_full_test() {
  let assert Ok(store) = cache.start(2)
  cache.write(store, "a", "first", 100)
  cache.write(store, "b", "second", 50)
  cache.write(store, "c", "third", 200)

  cache.read(store, "b") |> should.equal(None)
  cache.read(store, "a") |> should.equal(Some(cache.Entry("first", 100)))
  cache.read(store, "c") |> should.equal(Some(cache.Entry("third", 200)))
}

pub fn rewriting_a_key_evicts_nothing_test() {
  let assert Ok(store) = cache.start(2)
  cache.write(store, "a", "first", 100)
  cache.write(store, "b", "second", 50)
  cache.write(store, "b", "again", 300)

  cache.read(store, "a") |> should.equal(Some(cache.Entry("first", 100)))
  cache.read(store, "b") |> should.equal(Some(cache.Entry("again", 300)))
}
