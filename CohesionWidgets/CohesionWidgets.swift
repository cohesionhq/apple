import SwiftUI
import WidgetKit

/// The app's widgets: the agents that need the user, a view of the tasks and
/// an agent's agenda on the Home Screen (the agenda on the Lock Screen too), cohesiond's activities together in one Live Activity, and the controls.
@main
struct CohesionWidgets: WidgetBundle {
    var body: some Widget {
        AgentsWidget()
        TasksWidget()
        AgentAgendaWidget()
        ActivitiesLiveActivity()
        AddTaskControl()
        AgentChatControl()
        NewActorSessionControl()
    }
}
