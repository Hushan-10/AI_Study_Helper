"""jactastic - Entry Point.

Combines server-side endpoints with client-side UI.
"""

# Import server-side data models and walkers
sv {
    import from endpoints { student_level, Quiz,
        task_manager, quiz_answer_walker, levelwalker}
}

# Client-side UI
cl {
    import from .frontend { app as ClientApp }

    def:pub app -> any {
        return
            <ClientApp />;
    }
}
