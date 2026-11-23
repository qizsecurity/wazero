package adhoc

import (
	"context"
	_ "embed"
	"testing"
	"time"

	"github.com/tetratelabs/wazero"
	"github.com/tetratelabs/wazero/api"
	"github.com/tetratelabs/wazero/experimental"
	"github.com/tetratelabs/wazero/internal/platform"
	"github.com/tetratelabs/wazero/internal/testing/require"
)

// loopcheck_depth.wat (qiz fork): infinite loops that sit one, two or three calls deep, and a loop that tail-calls itself. The
// host function `stop` closes the module when the global `n` (counted by every loop body) reaches the global `k`, so `n` at the
// end of the call is how many loop iterations ran before compiled code noticed the close: it must not depend on how deep the loop is.
//
//go:embed testdata/loopcheck_depth.wasm
var loopcheckDepthWasm []byte

// loopcheckBound is wazevoapi.LoopCheckBudget times two: the check is every LoopCheckBudget iterations of all the frames of one
// call together; the margin allows for the iterations that ran before the stop was requested (k).
const loopcheckBound = 2 * (1 << 14)

//go:embed testdata/loopcheck_eh.wasm
var loopcheckEHWasm []byte

func runLoopcheckDepth(t *testing.T, fn string, k uint64) (n uint64, stopped bool) {
	return runLoopcheck(t, loopcheckDepthWasm, fn, k)
}

func runLoopcheck(t *testing.T, wasm []byte, fn string, k uint64) (n uint64, stopped bool) {
	ctx := context.Background()
	cfg := wazero.NewRuntimeConfigCompiler().WithCloseOnContextDone(true).
		WithCoreFeatures(api.CoreFeaturesV2 | experimental.CoreFeaturesTailCall | experimental.CoreFeaturesExceptionHandling)
	r := wazero.NewRuntimeWithConfig(ctx, cfg)
	defer r.Close(ctx)
	_, err := r.NewHostModuleBuilder("env").NewFunctionBuilder().
		WithFunc(func(ctx context.Context, m api.Module) { _ = m.CloseWithExitCode(ctx, 7) }).Export("stop").
		Instantiate(ctx)
	require.NoError(t, err)
	mod, err := r.Instantiate(ctx, wasm)
	require.NoError(t, err)
	mod.ExportedGlobal("k").(api.MutableGlobal).Set(k)
	done := make(chan struct{})
	go func() {
		defer close(done)
		_, _ = mod.ExportedFunction(fn).Call(ctx)
	}()
	select {
	case <-done:
		return mod.ExportedGlobal("n").Get(), true
	case <-time.After(5 * time.Second):
		return 0, false // the guest is still running: the test process cannot stop it, the caller fails the test
	}
}

func TestLoopCheck_StopBoundIsIndependentOfCallDepth(t *testing.T) {
	if !platform.CompilerSupported() {
		t.Skip()
	}
	for _, fn := range []string{"single", "nested", "depth2", "depth3", "tailloop"} {
		t.Run(fn, func(t *testing.T) {
			n, stopped := runLoopcheckDepth(t, fn, 5)
			if !stopped {
				t.Fatalf("%s: the module was closed after 5 iterations and the guest was still running 5 s later", fn)
			}
			if n > 5+loopcheckBound {
				t.Fatalf("%s: %d iterations ran after the close was requested at 5, want at most %d", fn, n-5, loopcheckBound)
			}
		})
	}
}

func TestLoopCheck_StopBoundSurvivesAnException(t *testing.T) {
	if !platform.CompilerSupported() {
		t.Skip()
	}
	n, stopped := runLoopcheck(t, loopcheckEHWasm, "ehdepth2", 5)
	if !stopped {
		t.Fatal("the module was closed after 5 iterations and the guest was still running 5 s later")
	}
	if n > 5+loopcheckBound {
		t.Fatalf("%d iterations ran after the close was requested at 5, want at most %d", n-5, loopcheckBound)
	}
}

// The new code must not change what a guest computes: a loop with 24 live i64 locals and calls inside crosses the budget
// several times, with the flag on and off.
func TestLoopCheck_ResultsDoNotChange(t *testing.T) {
	if !platform.CompilerSupported() {
		t.Skip()
	}
	call := func(on bool, fn string, arg uint64) uint64 {
		ctx := context.Background()
		cfg := wazero.NewRuntimeConfigCompiler().WithCloseOnContextDone(on).
			WithCoreFeatures(api.CoreFeaturesV2 | experimental.CoreFeaturesTailCall)
		r := wazero.NewRuntimeWithConfig(ctx, cfg)
		defer r.Close(ctx)
		_, err := r.NewHostModuleBuilder("env").NewFunctionBuilder().WithFunc(func() {}).Export("stop").Instantiate(ctx)
		require.NoError(t, err)
		mod, err := r.Instantiate(ctx, loopcheckDepthWasm)
		require.NoError(t, err)
		out, err := mod.ExportedFunction(fn).Call(ctx, arg)
		require.NoError(t, err)
		return out[0]
	}
	for _, fn := range []string{"pressure", "sum"} {
		require.Equal(t, call(false, fn, 100000), call(true, fn, 100000))
	}
	require.Equal(t, uint64(4999950000), call(true, "sum", 100000))
}
