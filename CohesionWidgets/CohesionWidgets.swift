import SwiftUI
import WidgetKit

/// The app's widgets: the agents that need the user and a view of the tasks
/// on the Home Screen, cohesiond's activities together in one Live Activity, and the controls.
@main
struct CohesionWidgets: WidgetBundle {
    var body: some Widget {
        AgentsWidget()
        TasksWidget()
        ActivitiesLiveActivity()
        AddTaskControl()
        AgentChatControl()
        NewActorSessionControl()
    }
}
