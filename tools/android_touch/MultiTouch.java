import android.os.SystemClock;
import android.view.InputDevice;
import android.view.InputEvent;
import android.view.MotionEvent;
import java.io.BufferedReader;
import java.io.InputStreamReader;
import java.lang.reflect.Method;
import java.util.ArrayList;

/** Shell-only diagnostic injector. Input: offset_ms action count x0 y0 [x1 y1]. */
public final class MultiTouch {
    private static void clockAnchor(String stage) {
        // Android nanoTime uses CLOCK_MONOTONIC, as do SF present timestamps.
        // Bracket the millisecond wall-clock read; never use elapsedRealtime
        // here (CLOCK_BOOTTIME includes suspend). Keep this outside timed input.
        long before = System.nanoTime();
        long epoch = System.currentTimeMillis();
        long after = System.nanoTime();
        // Separate bracket for atrace's boot clock; preserve wall-read precision.
        long bootBefore = System.nanoTime();
        long boot = SystemClock.elapsedRealtimeNanos();
        long bootAfter = System.nanoTime();
        System.err.println("ANDROID_TOUCH_CLOCK {\"stage\":\"" + stage
                + "\",\"monotonic_before_ns\":" + before
                + ",\"epoch_ms\":" + epoch
                + ",\"monotonic_after_ns\":" + after
                + ",\"boot_monotonic_before_ns\":" + bootBefore
                + ",\"boottime_ns\":" + boot
                + ",\"boot_monotonic_after_ns\":" + bootAfter + "}");
    }

    public static void main(String[] args) throws Exception {
        long started = SystemClock.uptimeMillis();
        clockAnchor("start");
        Class<?> managerClass;
        try {
            // Modern Android moved shell input injection to InputManagerGlobal.
            managerClass = Class.forName("android.hardware.input.InputManagerGlobal");
            managerClass.getMethod("getInstance");
            managerClass.getMethod("injectInputEvent", InputEvent.class, int.class);
        } catch (ClassNotFoundException | NoSuchMethodException unavailable) {
            managerClass = Class.forName("android.hardware.input.InputManager");
        }
        Object manager = managerClass.getMethod("getInstance").invoke(null);
        Method inject = managerClass.getMethod("injectInputEvent", InputEvent.class, int.class);
        long down = SystemClock.uptimeMillis();
        // Keep stdout transport off the timed input path. Preserve receipts on
        // failure as well: the host still rejects an incomplete event stream.
        StringBuilder receipts = new StringBuilder();
        MotionEvent last = null;
        boolean active = false;
        try (BufferedReader input = new BufferedReader(new InputStreamReader(System.in))) {
            String line;
            // Prepare the entire bounded script before starting its clock. Regex
            // parsing and pointer-array allocation must not delay timed MOVE events.
            ArrayList<Long> offsets = new ArrayList<>();
            ArrayList<Integer> actions = new ArrayList<>();
            ArrayList<MotionEvent.PointerProperties[]> allProperties = new ArrayList<>();
            ArrayList<MotionEvent.PointerCoords[]> allCoords = new ArrayList<>();
            long previous = -1;
            while ((line = input.readLine()) != null) {
                String[] fields = line.trim().split("\\s+");
                long offset = Long.parseLong(fields[0]);
                int action = Integer.parseInt(fields[1]);
                int count = Integer.parseInt(fields[2]);
                if (offsets.size() >= 4096 || offset < 0 || offset < previous || offset > 10000 || count < 1 || count > 2
                        || fields.length != 3 + count * 2)
                    throw new IllegalArgumentException("Invalid bounded touch event");
                previous = offset;
                MotionEvent.PointerProperties[] properties = new MotionEvent.PointerProperties[count];
                MotionEvent.PointerCoords[] coords = new MotionEvent.PointerCoords[count];
                for (int i = 0; i < count; i++) {
                    properties[i] = new MotionEvent.PointerProperties();
                    properties[i].id = i;
                    properties[i].toolType = MotionEvent.TOOL_TYPE_FINGER;
                    coords[i] = new MotionEvent.PointerCoords();
                    coords[i].x = Float.parseFloat(fields[3 + i * 2]);
                    coords[i].y = Float.parseFloat(fields[4 + i * 2]);
                    coords[i].pressure = 1;
                    coords[i].size = 1;
                }
                offsets.add(offset);
                actions.add(action);
                allProperties.add(properties);
                allCoords.add(coords);
            }
            down = SystemClock.uptimeMillis();
            for (int sequence = 0; sequence < offsets.size(); sequence++) {
                int action = actions.get(sequence);
                MotionEvent.PointerProperties[] properties = allProperties.get(sequence);
                MotionEvent.PointerCoords[] coords = allCoords.get(sequence);
                long wait = down + offsets.get(sequence) - SystemClock.uptimeMillis();
                if (wait > 0) SystemClock.sleep(wait);
                MotionEvent event = MotionEvent.obtain(down, SystemClock.uptimeMillis(),
                        action, properties.length, properties, coords, 0, 0, 1, 1, 0, 0,
                        InputDevice.SOURCE_TOUCHSCREEN, 0);
                if (last != null) last.recycle();
                last = event;
                // Mark active before injection so exceptions also attempt cleanup.
                active = true;
                if (!Boolean.TRUE.equals(inject.invoke(manager, event, 2)))
                    throw new IllegalStateException("Input injection rejected");
                active = (action & MotionEvent.ACTION_MASK) != MotionEvent.ACTION_UP;
                receipts.append(sequence).append(' ').append(event.getEventTime())
                        .append(' ').append(action).append('\n');
            }
            if (active) throw new IllegalArgumentException("Touch stream ended before UP");
        } finally {
            try {
                if (active && last != null) {
                    MotionEvent cancel = MotionEvent.obtain(last);
                    cancel.setAction(MotionEvent.ACTION_CANCEL);
                    try { inject.invoke(manager, cancel, 2); }
                    finally { cancel.recycle(); }
                }
            } finally {
                if (last != null) last.recycle();
                long injectionEnd = SystemClock.uptimeMillis();
                clockAnchor("injection_end");
                System.out.print(receipts.toString());
                System.out.flush();
                System.err.println("ANDROID_TOUCH_TIMING start_uptime_ms=" + started
                        + " ready_uptime_ms=" + down
                        + " injection_end_uptime_ms=" + injectionEnd
                        + " receipts_end_uptime_ms=" + SystemClock.uptimeMillis());
            }
        }
        // This is a one-shot shell process. All synchronous injections, pointer
        // cleanup and receipts are complete; avoid waiting for VM teardown
        // between combat gestures. Exceptions still propagate with failure.
        System.err.flush();
        System.exit(0);
    }
}
