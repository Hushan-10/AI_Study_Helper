import from byllm.lib { Model }
# import from tavily { TavilyClient }
import os;
import time;

glob llm = Model(model_name="gpt-4o-mini");
# glob tavily_client = TavilyClient(api_key=os.getenv("TAVILY_API_KEY"));

def infer_quiz_count(text: str) -> int {
    t = text.lower();

    if ("one" in t or "single" in t) and ("question" in t or "mcq" in t or "quiz" in t) {
        return 1;
    }

    tokens = t.replace("\n", " ").replace(",", " ").split(" ");
    for tok in tokens {
        if tok.isdigit() {
            n = int(tok);
            if n > 0 and n <= 50 {
                return n;
            }
        }
    }

    return 5;
}

node AppState {
    has created_at: str = "";
}

def ensure_app_state() -> AppState {
    st = [root -->(`?AppState)];
    if st { return st[0]; }

    created = [root ++> AppState(created_at=str(time.time()))];
    return created[0];
}

node student_level {
    has level: str = "beginner",
        percentage: float = 0.0,
        full_score: int = 0;

    can execute with levelwalker entry {
        print("[Student Level Node Activated]");

        quizzes = [self -->(`?Quiz)];
        self.full_score = 0;
        student_score = 0;

        for q in quizzes {
            self.full_score += 1;
            student_score += q.score;
        }

        if self.full_score > 0 {
            self.percentage = (student_score * 100.0) / self.full_score;
        }
        else {
            self.percentage = 0.0;
        }

        if self.percentage >= 80.0 {
            self.level = "advanced";
        }
        elif self.percentage >= 50.0 {
            self.level = "intermediate";
        }
        else {
            self.level = "beginner";
        }

        report {
            "level": self.level,
            "percentage": self.percentage,
            "full_score": self.full_score
        };
    }
}

node Quiz {
    has question: str = "",
        options: str = "",
        correct_answer: str = "",
        score: int = 0;
}

sem Quiz = "A single multiple-choice question (MCQ).";
sem Quiz.question = "Text of the MCQ question.";
sem Quiz.options = "All answer options in a formatted string, typically numbered 1-4.";
sem Quiz.correct_answer = "The correct option number as a string: '1', '2', '3', or '4'.";

def ensure_student_level() -> student_level {
    app = ensure_app_state();

    lvl = [app -->(`?student_level)];
    if lvl { return lvl[0]; }

    created = [app ++> student_level(level="beginner")];
    return created[0];
}


enum RoutingNodes {
    QUIZ_HANDLING,
    SUMMARIZER_HANDLING,
    FLASHCARD_HANDLING,
    EXPLANATION_HANDLING
}

obj TaskPartition {
    has task: str,
        agent_type: RoutingNodes;
}

node QuizHandling {
    def create_quiz(question: str, options: str, correct_answer: str) -> str {
        print(f"[Quiz Created]: {question}");

        lvl = ensure_student_level();

        created = self ++> Quiz(
            question=question,
            options=options,
            correct_answer=correct_answer,
            score=0
        );

        if created {
            lvl ++> created[0];
        }

        return "Quiz question added successfully";
    }

    def route_and_generate(utterance: str) -> str by llm(
        method="ReAct",
        tools=([self.create_quiz])
        # tools=([self.create_quiz, self.tavily_search])
    );

    can execute with task_manager entry {
        print("[QuizHandling Node Activated]");

        n = infer_quiz_count(visitor.utterance);

        before = [self -->(`?Quiz)];
        before_len = len(before);

        full_prompt = f"""
        {visitor.cur_task.task}

        Here is the study text from the student:
        {visitor.utterance}

        Create EXACTLY {n} MCQs.

        STRICT RULES:
        - For EACH question you MUST call the tool create_quiz(question, options, correct_answer).
        - correct_answer MUST be one of: "1", "2", "3", "4" (string).
        - options MUST be formatted exactly as:
        1. ...
        2. ...
        3. ...
        4. ...

        Do not add commentary. Do not return JSON. Only use tool calls.
        """;

        _ = self.route_and_generate(full_prompt);

        after = [self -->(`?Quiz)];
        new_quizzes = after[before_len:];

        quiz_text = "";
        idx = 1;
        for q in new_quizzes {
            quiz_text += f"{idx}. {q.question}\n\n";
            quiz_text += f"{q.options}\n\n";
            idx += 1;
        }

        # IMPORTANT: push into visitor.results so task_manager can return it
        visitor.results.append({
            "type": "quiz",
            "task": visitor.cur_task.task,
            "output": quiz_text
        });
    }
}

node SummarizerHandling {
    def summarize_text(utterance: str) -> str by llm();

    can execute with task_manager entry {
        print("[SummarizerHandling Node Activated]");

        full_prompt = f"""
        Summarize the following text:

        {visitor.utterance}
        """;

        response = self.summarize_text(full_prompt);

        visitor.results.append({
            "type": "summary",
            "task": visitor.cur_task.task,
            "output": response
        });
    }
}

node ExplanationHandling {
    def explain_simple(utterance: str) -> str by llm();
    def explain_step_by_step(utterance: str) -> str by llm();

    def route_and_run(utterance: str) -> str by llm(
        method="ReAct",
        tools=([self.explain_simple, self.explain_step_by_step])
    );

    can execute with task_manager entry {
        print("[ExplanationHandling Node Activated]");

        lvl = ensure_student_level();
        level_str = lvl.level;

        full_prompt = f"""
        You are an explanation agent with two tools:
        - explain_simple: short, concise explanation.
        - explain_step_by_step: detailed explanation broken into steps.

        Student level: {level_str}

        Rules:
        - beginner: use ONLY explain_step_by_step
        - intermediate: may combine, but include steps
        - advanced: use ONLY explain_simple

        Explain this:
        {visitor.utterance}
        """;

        response = self.route_and_run(full_prompt);

        visitor.results.append({
            "type": "explanation",
            "task": visitor.cur_task.task,
            "output": response
        });
    }
}

node FlashcardHandling {
    def create_flashcards(source_text: str) -> str by llm();

    def route_and_run(utterance: str) -> str by llm(
        method="ReAct",
        tools=([self.create_flashcards])
    );

    can execute with task_manager entry {
        print("[FlashcardHandling Node Activated]");

        full_prompt = f"""
{visitor.cur_task.task}

Create flashcards from this text:
{visitor.utterance}
""";

        response = self.route_and_run(full_prompt);

        visitor.results.append({
            "type": "flashcards",
            "task": visitor.cur_task.task,
            "output": response
        });
    }
}


walker:pub task_manager {
    has utterance: str = "",
        cur_task: TaskPartition = None,
        results: list = [];

    obj __specs__ {
        static has auth: bool = False;
    }

    def plan_tasks(main_task: str) -> list[TaskPartition] by llm();

    can start with `root entry {
        _ = ensure_app_state();
        _ = ensure_student_level();

        # Ensure agent nodes exist under AppState (stable across requests)
        app = ensure_app_state();

        quiz_nodes = [app -->(`?QuizHandling)];
        if not quiz_nodes { quiz_nodes = [app ++> QuizHandling()]; }

        sum_nodes = [app -->(`?SummarizerHandling)];
        if not sum_nodes { sum_nodes = [app ++> SummarizerHandling()]; }

        flash_nodes = [app -->(`?FlashcardHandling)];
        if not flash_nodes { flash_nodes = [app ++> FlashcardHandling()]; }

        exp_nodes = [app -->(`?ExplanationHandling)];
        if not exp_nodes { exp_nodes = [app ++> ExplanationHandling()]; }

        subtasks = self.plan_tasks(self.utterance);

        # Run subtasks and collect typed results in self.results
        for subtask in subtasks {
            self.cur_task = subtask;

            if subtask.agent_type == RoutingNodes.QUIZ_HANDLING {
                visit quiz_nodes[0];
            }
            elif subtask.agent_type == RoutingNodes.SUMMARIZER_HANDLING {
                visit sum_nodes[0];
            }
            elif subtask.agent_type == RoutingNodes.FLASHCARD_HANDLING {
                visit flash_nodes[0];
            }
            elif subtask.agent_type == RoutingNodes.EXPLANATION_HANDLING {
                visit exp_nodes[0];
            }
        }

        report {
            "ok": True,
            "results": self.results
        };
    }
}

walker:pub quiz_answer_walker {
    has user_answer: str = "";

    obj __specs__ {
        static has auth: bool = False;
    }

    can start with `root entry {
        lvl = ensure_student_level();

        quizzes = [lvl -->(`?Quiz)];
        if not quizzes {
            report {"ok": False, "message": "No quiz available. Generate a quiz first."};
            return;
        }

        q = quizzes[len(quizzes) - 1];

        user = self.user_answer.strip();
        correct = q.correct_answer.strip();

        is_correct = False;
        msg = "";

        if user == correct {
            q.score += 1;
            is_correct = True;
            msg = "Correct! 🎉";
        }
        else {
            msg = f"Incorrect. The correct answer is: {q.correct_answer}";
        }

        # Recompute level by visiting level node logic
        # (reuse the node's existing computation)
        # We call its execute block via spawn levelwalker in frontend anyway,
        # but also return quick status here.
        report {
            "ok": True,
            "correct": is_correct,
            "message": msg
        };
    }
}

walker:pub levelwalker {
    obj __specs__ {
        static has auth: bool = False;
    }

    can start with `root entry {
        lvl = ensure_student_level();
        visit lvl;
    }
}
