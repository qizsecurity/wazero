;; qiz fork: an infinite loop whose body catches an exception thrown by a callee that itself runs a 16000-iteration loop first.
;; The count of loop iterations shared by the frames of one call must also survive the unwinding of the throwing frame.
(module
  (import "env" "stop" (func $stop))
  (global $n (export "n") (mut i64) (i64.const 0))
  (global $k (export "k") (mut i64) (i64.const 0))
  (tag $e)
  (func $bump
    (global.set $n (i64.add (global.get $n) (i64.const 1)))
    (if (i64.eq (global.get $n) (global.get $k)) (then (call $stop))))
  (func $inner_throw (local $i i32)
    (loop $l (call $bump)
      (local.set $i (i32.add (local.get $i) (i32.const 1)))
      (br_if $l (i32.lt_u (local.get $i) (i32.const 16000))))
    (throw $e))
  (func (export "ehdepth2")
    (loop $o
      (block $c
        (try_table (catch_all $c) (call $inner_throw)))
      (br $o))))
