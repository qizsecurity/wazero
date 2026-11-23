(module
  (import "env" "stop" (func $stop))
  (global $n (export "n") (mut i64) (i64.const 0))
  (global $k (export "k") (mut i64) (i64.const 0))
  (table 1 funcref)
  (elem (i32.const 0) $inf)
  (type $v (func))
  (func $bump
    (global.set $n (i64.add (global.get $n) (i64.const 1)))
    (if (i64.eq (global.get $n) (global.get $k)) (then (call $stop))))
  ;; 1: one loop, back-edge by br
  (func (export "single")
    (loop $l (call $bump) (br $l)))
  ;; 2: nested loops: inner runs 100 iterations per outer iteration
  (func (export "nested") (local $i i32)
    (loop $o
      (local.set $i (i32.const 0))
      (loop $in
        (call $bump)
        (local.set $i (i32.add (local.get $i) (i32.const 1)))
        (br_if $in (i32.lt_u (local.get $i) (i32.const 100))))
      (br $o)))
  ;; 3: back-edge only through br_table
  (func (export "brtable")
    (loop $l (call $bump) (br_table $l $l (i32.const 0))))
  ;; 4: two loops in one function: first ends after 10, second is infinite
  (func (export "twoloops") (local $i i32)
    (loop $a
      (local.set $i (i32.add (local.get $i) (i32.const 1)))
      (br_if $a (i32.lt_u (local.get $i) (i32.const 10))))
    (loop $b (call $bump) (br $b)))
  (func $inf (loop $l (call $bump) (br $l)))
  ;; 5: loop reached via call_indirect
  (func (export "indirect") (call_indirect (type $v) (i32.const 0)))
  ;; 6: loop reached via return_call
  (func (export "retcall") (return_call $inf))
  ;; 7: loop with an i32 param and result, plus locals; crosses the budget several times
  (func (export "sum") (param $m i32) (result i64) (local $acc i64) (local $t i32)
    (i32.const 0)
    (loop $l (param i32) (result i32)
      (local.set $t)
      (local.set $acc (i64.add (local.get $acc) (i64.extend_i32_u (local.get $t))))
      (local.set $t (i32.add (local.get $t) (i32.const 1)))
      (local.get $t)
      (br_if $l (i32.lt_u (local.get $t) (local.get $m))))
    drop
    (local.get $acc))
  ;; 8: infinite loop with no host call (cancel by context only)
  (func (export "spin") (loop $l (br $l)))
  ;; 9: tail recursion with no loop (no check point upstream either)
  (func $tr (return_call $tr))
  (func (export "tailrec") (call $tr))

  (func $id (param i64) (result i64) (local.get 0))
  (func $inner16000 (local $i i32)
    (loop $l (call $bump)
      (local.set $i (i32.add (local.get $i) (i32.const 1)))
      (br_if $l (i32.lt_u (local.get $i) (i32.const 16000)))))
  ;; 10: outer loop calls a function whose own loop runs 16000 times and returns
  (func (export "depth2") (loop $o (call $inner16000) (br $o)))
  (func $mid (local $i i32)
    (loop $l (call $inner16000)
      (local.set $i (i32.add (local.get $i) (i32.const 1)))
      (br_if $l (i32.lt_u (local.get $i) (i32.const 16000)))))
  ;; 11: three frames deep
  (func (export "depth3") (loop $o (call $mid) (br $o)))
  ;; 12: register pressure plus calls inside the loop; crosses the budget many times
  (func (export "pressure") (param $m i32) (result i64) (local $t i32) (local $a0 i64) (local $a1 i64) (local $a2 i64) (local $a3 i64) (local $a4 i64) (local $a5 i64) (local $a6 i64) (local $a7 i64) (local $a8 i64) (local $a9 i64) (local $a10 i64) (local $a11 i64) (local $a12 i64) (local $a13 i64) (local $a14 i64) (local $a15 i64) (local $a16 i64) (local $a17 i64) (local $a18 i64) (local $a19 i64) (local $a20 i64) (local $a21 i64) (local $a22 i64) (local $a23 i64)
    (loop $l
      (local.set $a0 (i64.add (i64.mul (local.get $a0) (i64.const 3)) (i64.extend_i32_u (local.get $t)))) (local.set $a1 (i64.add (i64.mul (local.get $a1) (i64.const 5)) (i64.extend_i32_u (local.get $t)))) (local.set $a2 (i64.add (i64.mul (local.get $a2) (i64.const 7)) (i64.extend_i32_u (local.get $t)))) (local.set $a3 (i64.add (i64.mul (local.get $a3) (i64.const 9)) (i64.extend_i32_u (local.get $t)))) (local.set $a4 (i64.add (i64.mul (local.get $a4) (i64.const 11)) (i64.extend_i32_u (local.get $t)))) (local.set $a5 (i64.add (i64.mul (local.get $a5) (i64.const 13)) (i64.extend_i32_u (local.get $t)))) (drop (call $id (local.get $a5))) (local.set $a6 (i64.add (i64.mul (local.get $a6) (i64.const 15)) (i64.extend_i32_u (local.get $t)))) (local.set $a7 (i64.add (i64.mul (local.get $a7) (i64.const 17)) (i64.extend_i32_u (local.get $t)))) (local.set $a8 (i64.add (i64.mul (local.get $a8) (i64.const 19)) (i64.extend_i32_u (local.get $t)))) (local.set $a9 (i64.add (i64.mul (local.get $a9) (i64.const 21)) (i64.extend_i32_u (local.get $t)))) (local.set $a10 (i64.add (i64.mul (local.get $a10) (i64.const 23)) (i64.extend_i32_u (local.get $t)))) (local.set $a11 (i64.add (i64.mul (local.get $a11) (i64.const 25)) (i64.extend_i32_u (local.get $t)))) (drop (call $id (local.get $a11))) (local.set $a12 (i64.add (i64.mul (local.get $a12) (i64.const 27)) (i64.extend_i32_u (local.get $t)))) (local.set $a13 (i64.add (i64.mul (local.get $a13) (i64.const 29)) (i64.extend_i32_u (local.get $t)))) (local.set $a14 (i64.add (i64.mul (local.get $a14) (i64.const 31)) (i64.extend_i32_u (local.get $t)))) (local.set $a15 (i64.add (i64.mul (local.get $a15) (i64.const 33)) (i64.extend_i32_u (local.get $t)))) (local.set $a16 (i64.add (i64.mul (local.get $a16) (i64.const 35)) (i64.extend_i32_u (local.get $t)))) (local.set $a17 (i64.add (i64.mul (local.get $a17) (i64.const 37)) (i64.extend_i32_u (local.get $t)))) (drop (call $id (local.get $a17))) (local.set $a18 (i64.add (i64.mul (local.get $a18) (i64.const 39)) (i64.extend_i32_u (local.get $t)))) (local.set $a19 (i64.add (i64.mul (local.get $a19) (i64.const 41)) (i64.extend_i32_u (local.get $t)))) (local.set $a20 (i64.add (i64.mul (local.get $a20) (i64.const 43)) (i64.extend_i32_u (local.get $t)))) (local.set $a21 (i64.add (i64.mul (local.get $a21) (i64.const 45)) (i64.extend_i32_u (local.get $t)))) (local.set $a22 (i64.add (i64.mul (local.get $a22) (i64.const 47)) (i64.extend_i32_u (local.get $t)))) (local.set $a23 (i64.add (i64.mul (local.get $a23) (i64.const 49)) (i64.extend_i32_u (local.get $t)))) (drop (call $id (local.get $a23)))
      (local.set $t (i32.add (local.get $t) (i32.const 1)))
      (br_if $l (i32.lt_u (local.get $t) (local.get $m))))
    (i64.xor (i64.xor (i64.xor (i64.xor (i64.xor (i64.xor (i64.xor (i64.xor (i64.xor (i64.xor (i64.xor (i64.xor (i64.xor (i64.xor (i64.xor (i64.xor (i64.xor (i64.xor (i64.xor (i64.xor (i64.xor (i64.xor (i64.xor (local.get $a0) (local.get $a1)) (local.get $a2)) (local.get $a3)) (local.get $a4)) (local.get $a5)) (local.get $a6)) (local.get $a7)) (local.get $a8)) (local.get $a9)) (local.get $a10)) (local.get $a11)) (local.get $a12)) (local.get $a13)) (local.get $a14)) (local.get $a15)) (local.get $a16)) (local.get $a17)) (local.get $a18)) (local.get $a19)) (local.get $a20)) (local.get $a21)) (local.get $a22)) (local.get $a23)))
  ;; 13: a loop of 10 iterations, then return_call to itself
  (func $tl (local $i i32)
    (loop $l (call $bump)
      (local.set $i (i32.add (local.get $i) (i32.const 1)))
      (br_if $l (i32.lt_u (local.get $i) (i32.const 10))))
    (return_call $tl))
  (func (export "tailloop") (call $tl))
)
