package com.pantrylens.pantrylens

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetProvider

open class PantryWidgetProvider : HomeWidgetProvider() {
    open val shopping = false
    override fun onUpdate(context: Context, manager: AppWidgetManager, ids: IntArray, data: SharedPreferences) {
        ids.forEach { id ->
            val views = RemoteViews(context.packageName, R.layout.pantry_widget)
            views.setTextViewText(R.id.widget_title, if (shopping) "Shopping list" else "Use soon")
            views.setTextViewText(R.id.widget_home, data.getString("home", "My home"))
            val content = data.getString(if (shopping) "shopping" else "useSoon", "")
            views.setContentDescription(R.id.widget_root, "${if (shopping) "Shopping list" else "Use soon"}. ${data.getString("home", "My home")}. ${content.orEmpty()}. Open PantryLens.")
            views.setTextViewText(R.id.widget_content, if (content.isNullOrBlank()) {
                if (shopping) "Your list is clear. Open PantryLens to add items." else "Nothing to use soon. Open PantryLens to review your pantry."
            } else content)
            views.setTextViewText(R.id.widget_updated, data.getString("updated", "Open PantryLens to update"))
            val launch = Intent(context, MainActivity::class.java).apply { flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP }
            views.setOnClickPendingIntent(R.id.widget_root, PendingIntent.getActivity(context, id, launch, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE))
            manager.updateAppWidget(id, views)
        }
    }
}

class ShoppingWidgetProvider : PantryWidgetProvider() { override val shopping = true }
