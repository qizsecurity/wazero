;; qiz fork: the loops that run inside a callee make no call, so nothing but the return, the throw or the call itself can
;; carry the loop budget out of the callee. The outer loop calls $bump once per iteration; the host function `stop` closes
;; the module when `n` reaches `k`. `m` counts the iterations of the callee's loop: how far the callee ran after the close
;; was requested is what the test bounds.
(module
  (import "env" "stop" (func $stop))
  (import "env" "tick" (func $tick))
  (global $n (export "n") (mut i64) (i64.const 0))
  (global $k (export "k") (mut i64) (i64.const 0))
  (global $m (export "m") (mut i64) (i64.const 0))
  (tag $e)
  (func $bump
    (global.set $n (i64.add (global.get $n) (i64.const 1)))
    (if (i64.eq (global.get $n) (global.get $k)) (then (call $stop))))
  (func $loop16000 (local $i i32)
    (loop $l
      (global.set $m (i64.add (global.get $m) (i64.const 1)))
      (local.set $i (i32.add (local.get $i) (i32.const 1)))
      (br_if $l (i32.lt_u (local.get $i) (i32.const 16000)))))
  (func $loop10 (local $i i32)
    (loop $l
      (global.set $m (i64.add (global.get $m) (i64.const 1)))
      (local.set $i (i32.add (local.get $i) (i32.const 1)))
      (br_if $l (i32.lt_u (local.get $i) (i32.const 10)))))
  ;; returns at the end of the body
  (func (export "ret_end") (loop $o (call $bump) (call $loop16000) (br $o)))
  ;; returns through a br_if to the function label
  (func $brif_ret (local $i i32)
    (loop $l
      (global.set $m (i64.add (global.get $m) (i64.const 1)))
      (local.set $i (i32.add (local.get $i) (i32.const 1)))
      (br_if $l (i32.lt_u (local.get $i) (i32.const 16000))))
    (br_if 0 (i32.const 1)))
  (func (export "ret_brif") (loop $o (call $bump) (call $brif_ret) (br $o)))
  ;; returns through the return instruction
  (func $explicit_ret (local $i i32)
    (loop $l
      (global.set $m (i64.add (global.get $m) (i64.const 1)))
      (local.set $i (i32.add (local.get $i) (i32.const 1)))
      (br_if $l (i32.lt_u (local.get $i) (i32.const 16000))))
    (return))
  (func (export "ret_return") (loop $o (call $bump) (call $explicit_ret) (br $o)))
  ;; a short callee: the outer loop's own iterations must count too
  (func (export "short_callee") (loop $o (call $bump) (call $loop10) (br $o)))
  ;; a throw out of the callee, caught in the outer loop
  (func $thrower (local $i i32)
    (loop $l
      (global.set $m (i64.add (global.get $m) (i64.const 1)))
      (local.set $i (i32.add (local.get $i) (i32.const 1)))
      (br_if $l (i32.lt_u (local.get $i) (i32.const 16000))))
    (throw $e))
  (func (export "throw_caught") (loop $o (call $bump) (block $c (try_table (catch_all $c) (call $thrower))) (br $o)))
  ;; the loop, the try_table, the inner loop and the throw in one function
  (func (export "throw_same_frame") (local $i i32)
    (loop $o (call $bump)
      (block $c
        (try_table (catch_all $c)
          (local.set $i (i32.const 0))
          (loop $in
            (global.set $m (i64.add (global.get $m) (i64.const 1)))
            (local.set $i (i32.add (local.get $i) (i32.const 1)))
            (br_if $in (i32.lt_u (local.get $i) (i32.const 16000))))
          (throw $e)))
      (br $o)))
  ;; no loop in any callee: only the outer loop's own iterations count, across a try_table entry
  (func (export "try_only") (loop $o (block $c (try_table (catch_all $c) (call $bump))) (br $o)))
  ;; returns through a br_table whose labels are the function label
  (func $brtable_ret (local $i i32)
    (loop $l
      (global.set $m (i64.add (global.get $m) (i64.const 1)))
      (local.set $i (i32.add (local.get $i) (i32.const 1)))
      (br_if $l (i32.lt_u (local.get $i) (i32.const 16000))))
    (br_table 0 0 (i32.const 0)))
  (func (export "ret_brtable") (loop $o (call $bump) (call $brtable_ret) (br $o)))
  ;; the outer loop calls local functions that hold no loop, call or throw (the caller keeps the budget in its register around
  ;; them) and one callee with a loop: the budget must still reach zero
  (func $leaf (param i32) (result i32) (i32.add (local.get 0) (i32.const 1)))
  (func (export "leaf_and_loop") (local $i i32)
    (loop $o (call $bump)
      (local.set $i (call $leaf (local.get $i)))
      (local.set $i (call $leaf (local.get $i)))
      (call $loop16000)
      (br $o)))
  ;; the only call of the loop is to an imported host function: it stops by the context only (host_only has no stop)
  (func (export "host_only") (loop $o (call $tick) (br $o))))
