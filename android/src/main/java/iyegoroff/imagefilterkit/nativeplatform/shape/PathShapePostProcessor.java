package iyegoroff.imagefilterkit.nativeplatform.shape;

import android.graphics.Canvas;
import android.graphics.Color;
import android.graphics.Paint;
import android.graphics.Path;

import com.facebook.cache.common.CacheKey;
import com.facebook.cache.common.SimpleCacheKey;

import org.json.JSONObject;

import java.util.Locale;

import javax.annotation.Nonnull;
import javax.annotation.Nullable;

import iyegoroff.imagefilterkit.InputConverter;
import iyegoroff.imagefilterkit.utility.GeneratorPostProcessor;

public class PathShapePostProcessor extends GeneratorPostProcessor {

  private @Nonnull final Path mPath;
  private @Nonnull final String mPathAsString;
  private final float mRotation;
  private final int mColor;

  public PathShapePostProcessor(int width, int height, @Nullable JSONObject config) {
    super(width, height, config);

    InputConverter converter = new InputConverter(width, height);

    mPath = converter.convertPath(config != null ? config.optJSONObject("path") : null, new Path());
    mPathAsString = config != null ? config.optJSONObject("path").toString() : "";
    mRotation = converter.convertScalar(config != null ? config.optJSONObject("rotation") : null, 0);
    mColor = converter.convertColor(config != null ? config.optJSONObject("color") : null, Color.BLACK);
  }

  @Override
  public String getName () {
    return "PathShapePostProcessor";
  }

  @Override
  public void processGenerated(@Nonnull Paint paint, @Nonnull Canvas canvas) {
    paint.setAntiAlias(true);
    paint.setColor(mColor);
    final float centerX = mWidth / 2.0f;
    final float centerY = mHeight / 2.0f;

    canvas.scale(1.0f, -1.0f, centerX, centerY);
    canvas.translate(centerX, centerY);
    canvas.rotate((float) Math.toDegrees(mRotation));

    canvas.drawPath(mPath, paint);
  }

  @Nonnull
  @Override
  public CacheKey generateCacheKey() {
    return new SimpleCacheKey(
      String.format(
        (Locale) null,
        "path_shape_%s_%f_%d_%d_%d",
        mPathAsString,
        mRotation,
        mColor,
        mWidth,
        mHeight
      )
    );
  }
}