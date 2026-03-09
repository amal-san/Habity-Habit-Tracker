package com.jeet_studio.habity



import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.graphics.BitmapFactory
import android.net.Uri

import android.view.View
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetBackgroundIntent
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider
import java.io.File

class FitdyWidgetProvider : HomeWidgetProvider() {

    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray, widgetData: SharedPreferences) {
        for (appWidgetId in appWidgetIds) {
            val views = RemoteViews(context.packageName, R.layout.widget_layout)

            val habitId = widgetData.getInt("widget_${appWidgetId}_id", -1)
            val habitName = widgetData.getString("widget_${appWidgetId}_name", "Tap to set up habit")

            views.setTextViewText(R.id.habit_name, habitName)

            if (habitId == -1) {
                val pendingIntent = HomeWidgetLaunchIntent.getActivity(
                    context,
                    MainActivity::class.java,
                    Uri.parse("fitdy://configure?widgetId=$appWidgetId")
                )
                views.setOnClickPendingIntent(R.id.widget_root, pendingIntent)
                views.setViewVisibility(R.id.habit_check, View.GONE)
                views.setViewVisibility(R.id.heatmap_image, View.GONE)
            } else {
                views.setViewVisibility(R.id.habit_check, View.VISIBLE)

                // --- THE DEBUGGING FIX ---
                val heatmapFilePath = widgetData.getString("habit_${habitId}_heatmap", null)


                if (heatmapFilePath != null) {
                    val file = File(heatmapFilePath)


                    if (file.exists()) {
                        try {
                            val bitmap = BitmapFactory.decodeFile(file.absolutePath)
                            if (bitmap != null) {
                                views.setImageViewBitmap(R.id.heatmap_image, bitmap)
                                views.setViewVisibility(R.id.heatmap_image, View.VISIBLE)
                            } else {
                                views.setViewVisibility(R.id.heatmap_image, View.GONE)
                            }
                        } catch (e: Exception) {
                            views.setViewVisibility(R.id.heatmap_image, View.GONE)
                        }
                    } else {
                        views.setViewVisibility(R.id.heatmap_image, View.GONE)
                    }
                } else {
                    views.setViewVisibility(R.id.heatmap_image, View.GONE)
                }

                // Checkmark logic
                val isDoneToday = widgetData.getBoolean("habit_${habitId}_day_0", false)
                if (isDoneToday) {
                    views.setImageViewResource(R.id.habit_check, android.R.drawable.checkbox_on_background)
                } else {
                    views.setImageViewResource(R.id.habit_check, android.R.drawable.checkbox_off_background)
                }

                val backgroundIntent = HomeWidgetBackgroundIntent.getBroadcast(
                    context, Uri.parse("fitdy://tickhabit?id=$habitId")
                )
                views.setOnClickPendingIntent(R.id.habit_check, backgroundIntent)

                val openPending = HomeWidgetLaunchIntent.getActivity(
                    context,
                    MainActivity::class.java,
                    Uri.parse("fitdy://home")
                )
                views.setOnClickPendingIntent(R.id.widget_root, openPending)
            }

            appWidgetManager.updateAppWidget(appWidgetId, views)
        }
    }
}