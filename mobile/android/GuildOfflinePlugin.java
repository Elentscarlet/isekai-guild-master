package com.godot.game;

import android.util.Log;
import com.chaquo.python.Python;
import com.chaquo.python.android.AndroidPlatform;
import org.godotengine.godot.Godot;
import org.godotengine.godot.plugin.GodotPlugin;
import org.godotengine.godot.plugin.UsedByGodot;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;

/** Keep the same socket adapter and rules engine on desktop and Android. */
public final class GuildOfflinePlugin extends GodotPlugin {
    private final ExecutorService worker = Executors.newSingleThreadExecutor();

    public GuildOfflinePlugin(Godot godot) { super(godot); }

    @Override public String getPluginName() { return "GuildOffline"; }

    @UsedByGodot public void start(String endpoint) {
        worker.execute(() -> {
            try {
                if (!Python.isStarted()) Python.start(new AndroidPlatform(getActivity()));
                Python.getInstance().getModule("mobile_bridge").callAttr("start", endpoint);
            } catch (Exception exception) {
                Log.e("GuildOffline", "Could not start the local rules", exception);
                try {
                    try (java.io.FileOutputStream output = new java.io.FileOutputStream(endpoint.replaceFirst("\\.json$", ".error"))) {
                        output.write(exception.toString().getBytes(java.nio.charset.StandardCharsets.UTF_8));
                    }
                } catch (Exception ignored) { }
            }
        });
    }

    @UsedByGodot public void stop() {
        worker.execute(() -> {
            if (Python.isStarted()) Python.getInstance().getModule("mobile_bridge").callAttr("stop");
        });
    }

    @Override public void onMainDestroy() { stop(); worker.shutdown(); }
}
