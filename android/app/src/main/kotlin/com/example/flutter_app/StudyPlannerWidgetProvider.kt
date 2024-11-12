package com.example.flutter_app

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.widget.RemoteViews
import android.util.Log
import com.google.firebase.firestore.FirebaseFirestore
import com.google.firebase.firestore.Query
import com.google.firebase.firestore.QuerySnapshot
import es.antonborri.home_widget.HomeWidgetProvider
import java.text.SimpleDateFormat
import java.util.*

class StudyPlannerWidgetProvider : HomeWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences
    ) {
        appWidgetIds.forEach { widgetId ->
            val views = RemoteViews(context.packageName, R.layout.study_planner_widget_layout).apply {
                // Set current date
                setTextViewText(R.id.widget_date, getCurrentDate())

                // Set icon
                setImageViewResource(R.id.widget_icon, R.drawable.ic_study_planner)

                // Fetch data from Firestore
                val db = FirebaseFirestore.getInstance()
                val studentNumber = widgetData.getString("studentNumber", "").orEmpty()

                Log.d("StudyPlannerWidget", "Student Number: $studentNumber")

                if (studentNumber.isNotEmpty()) {
                    // Fetch To Do tasks
                    fetchTasks(db, studentNumber, "To Do", R.id.widget_todo_list, appWidgetManager, widgetId)

                    // Fetch Missed tasks
                    fetchTasks(db, studentNumber, "Missed", R.id.widget_missed_list, appWidgetManager, widgetId)
                } else {
                    Log.d("StudyPlannerWidget", "Student number not set.")
                    setTextViewText(R.id.widget_todo_list, "Student number not set")
                    setTextViewText(R.id.widget_missed_list, "Student number not set")
                    appWidgetManager.updateAppWidget(widgetId, this)
                }

                // Set up a PendingIntent to launch the app when the widget is clicked
                val intent = context.packageManager.getLaunchIntentForPackage(context.packageName)
                intent?.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TASK)
                val pendingIntent = PendingIntent.getActivity(
                    context,
                    0,
                    intent,
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                )
                setOnClickPendingIntent(R.id.widget_container, pendingIntent)
            }
            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }

    private fun fetchTasks(
        db: FirebaseFirestore,
        studentNumber: String,
        status: String,
        textViewId: Int,
        appWidgetManager: AppWidgetManager,
        widgetId: Int
    ) {
        db.collection("users")
            .document(studentNumber)
            .collection("to-do-files")
            .whereEqualTo("status", status)
            .orderBy("endTime", if (status == "To Do") Query.Direction.ASCENDING else Query.Direction.DESCENDING)
            .limit(3)
            .get()
            .addOnSuccessListener { documents: QuerySnapshot ->
                var taskText = ""
                for (document in documents) {
                    val subject = document.getString("subject").orEmpty()
                    val endTime = document.getTimestamp("endTime")?.toDate()
                    val formattedDate = endTime?.let { formatDate(it) }.orEmpty()
                    taskText += "• $subject ($formattedDate)\n"
                }
                Log.d("StudyPlannerWidget", "$status Tasks Loaded: $taskText")
                val views = RemoteViews(appWidgetManager.getAppWidgetInfo(widgetId).provider.packageName, R.layout.study_planner_widget_layout)
                views.setTextViewText(textViewId, taskText.ifEmpty { "No ${status.toLowerCase()} tasks" })
                appWidgetManager.updateAppWidget(widgetId, views)
            }
            .addOnFailureListener { exception ->
                Log.e("StudyPlannerWidget", "Failed to load $status tasks: ${exception.message}")
                val views = RemoteViews(appWidgetManager.getAppWidgetInfo(widgetId).provider.packageName, R.layout.study_planner_widget_layout)
                views.setTextViewText(textViewId, "Failed to load tasks")
                appWidgetManager.updateAppWidget(widgetId, views)
            }
    }

    private fun formatDate(date: Date): String {
        val format = SimpleDateFormat("MMM d, yyyy", Locale.getDefault())
        return format.format(date)
    }

    private fun getCurrentDate(): String {
        val format = SimpleDateFormat("EEEE, MMM d", Locale.getDefault())
        return format.format(Date())
    }

    companion object {
        fun updateWidget(context: Context) {
            val intent = Intent(context, StudyPlannerWidgetProvider::class.java)
            intent.action = AppWidgetManager.ACTION_APPWIDGET_UPDATE
            val ids = AppWidgetManager.getInstance(context)
                .getAppWidgetIds(android.content.ComponentName(context, StudyPlannerWidgetProvider::class.java))
            intent.putExtra(AppWidgetManager.EXTRA_APPWIDGET_IDS, ids)
            context.sendBroadcast(intent)
        }
    }
}