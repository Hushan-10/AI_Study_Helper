# """Todo App - Server-Side Data Layer.

# Each user gets their own todo list automatically!
# When authenticated, `root spawn` uses the user's personal root node.
# """

# # ========================================
# # Data Models
# # ========================================
# node Todo {
#     has id: str,
#         title: str,
#         completed: bool = False;
# }

# glob todo_counter: int = 0;

# # ========================================
# # Walkers (API Operations)
# # ========================================
# walker:priv AddTodo {
#     """Add a new todo item to the user's list."""
#     has title: str;

#     can create with `root entry {
#         global todo_counter;
#         todo_counter += 1;
#         new_id = "todo_" + str(todo_counter);
#         new_todo = here ++> Todo(id=new_id, title=self.title, completed=False);
#         if new_todo {
#             report new_todo[0] ;
#         }
#     }
# }

# walker:priv ListTodos {
#     """List all todo items for the current user."""
#     has todos: list = [];

#     can collect with `root entry {
#         visit [-->];
#     }

#     can gather with Todo entry {
#         self.todos.append(
#             {"id": here.id, "title": here.title, "completed": here.completed}
#         );
#     }

#     can report_all with `root exit {
#         report self.todos ;
#     }
# }

# walker:priv ToggleTodo {
#     """Toggle a todo's completed status."""
#     has todo_id: str;

#     can search with `root entry {
#         visit [-->];
#     }

#     can toggle with Todo entry {
#         if here.id == self.todo_id {
#             here.completed = not here.completed;
#             report {"id": here.id, "completed": here.completed} ;
#         }
#     }
# }

# walker:priv DeleteTodo {
#     """Delete a todo item."""
#     has todo_id: str;

#     can search with `root entry {
#         visit [-->];
#     }

#     can delete with Todo entry {
#         if here.id == self.todo_id {
#             del here ;
#             report {"deleted": self.todo_id} ;
#         }
#     }
# }


# """
# Study Assistant Backend (Updated Jac Syntax)

# Features:
# - Quiz generation with Tavily search tool
# - Summarization
# - Flashcards
# - Explanation (level-based)
# - Student level computation from quiz scores
# """

# import from byllm.lib { Model }
# # import from tavily { TavilyClient }
# import os;
# import time;

# glob llm = Model(model_name="gpt-4o");
# # glob tavily_client = TavilyClient(api_key=os.getenv("TAVILY_API_KEY"));

# # =========================================================
# # DATA NODES
# # =========================================================

# node StudentLevel {
#     has level: str = "beginner",
#         percentage: float = 0.0,
#         full_score: int = 0;
# }

# node Quiz {
#     has question: str = "",
#         options: str = "",
#         correct_answer: str = "",
#         score: int = 0;
# }

# sem Quiz = "A single multiple-choice question (MCQ).";
# sem Quiz.question = "Text of the MCQ question.";
# sem Quiz.options = "All answer options in a formatted string, typically numbered or lettered.";
# sem Quiz.correct_answer = "The correct option for this MCQ (e.g. 'B' or 'Option 3').";

# # =========================================================
# # ROUTING METADATA
# # =========================================================

# enum RoutingNodes {
#     QUIZ_HANDLING,
#     SUMMARIZER_HANDLING,
#     FLASHCARD_HANDLING,
#     EXPLANATION_HANDLING
# }

# sem RoutingNodes.QUIZ_HANDLING = "Generate and manage multiple-choice quiz questions (MCQs) from the user's request or study material.";
# sem RoutingNodes.SUMMARIZER_HANDLING = "Summarize user-provided text or documents into concise explanations or bullet points.";
# sem RoutingNodes.FLASHCARD_HANDLING = "Create flashcards for study purposes based on the user's input or source text.";
# sem RoutingNodes.EXPLANATION_HANDLING = "Provide simple or step-by-step explanations of concepts as requested by the user.";

# obj TaskPartition {
#     has task: str,
#         agent_type: RoutingNodes;
# }

# sem TaskPartition = "A sub-task derived from the user's main request.";
# sem TaskPartition.task = "Natural language description of this sub-task (e.g., 'create 5 MCQs on photosynthesis').";
# sem TaskPartition.agent_type = "Which specialized agent should process this sub-task.";

# # =========================================================
# # HELPERS (GRAPH / STATE)
# # =========================================================

# def ensure_student_level() -> StudentLevel {
#     level_nodes = [root -->(`?StudentLevel)];
#     if level_nodes {
#         return level_nodes[0];
#     }
#     new_nodes = [root ++> StudentLevel(level="beginner")];
#     return new_nodes[0];
# }

# def recompute_level() -> str {
#     level_node = ensure_student_level();

#     quizzes = [level_node -->(`?Quiz)];
#     level_node.full_score = 0;
#     student_score = 0;

#     for q in quizzes {
#         level_node.full_score += 1;
#         student_score += q.score;
#     }

#     if level_node.full_score > 0 {
#         level_node.percentage = (student_score * 100.0) / level_node.full_score;
#     }
#     else {
#         level_node.percentage = 0.0;
#     }

#     if level_node.percentage >= 80.0 {
#         level_node.level = "advanced";
#     }
#     elif level_node.percentage >= 50.0 {
#         level_node.level = "intermediate";
#     }
#     else {
#         level_node.level = "beginner";
#     }

#     return level_node.level;
# }

# def format_quizzes(qs: list) -> str {
#     quiz_text = "";
#     idx = 1;
#     for q in qs {
#         quiz_text += f"{idx}. {q.question}\n\n";
#         quiz_text += f"{q.options}\n\n";
#         idx += 1;
#     }
#     return quiz_text;
# }

# # =========================================================
# # TOOL FUNCTIONS (USED BY ReAct)
# # NOTE: these modify the graph, so they must be normal defs.
# # =========================================================

# def create_quiz(question: str, options: str, correct_answer: str) -> str {
#     level_node = ensure_student_level();

#     created = [root ++> Quiz(
#         question=question,
#         options=options,
#         correct_answer=correct_answer,
#         score=0
#     )];

#     # connect quiz to StudentLevel so scoring affects level
#     level_node ++> created[0];

#     return "Quiz question added successfully";
# }

# def tavily_search(topic: str) -> str {
#     search_results = tavily_client.search(topic, limit=3);
#     snippets = [r["content"] for r in search_results.get("results", []) if "content" in r];
#     return "\n".join(snippets);
# }

# # =========================================================
# # LLM FUNCTIONS (EXPORTED)
# # =========================================================

# """
# Quiz generator:
# - Uses ReAct
# - Tools: create_quiz (store in graph) + tavily_search (web snippets)
# """
# def:pub route_and_generate_quiz(prompt: str) -> str by llm(
#     method="ReAct",
#     tools=([create_quiz, tavily_search])
# );

# """Summarizer (plain LLM call)."""
# def:pub summarize_text(prompt: str) -> str by llm();

# """Flashcards (plain LLM call)."""
# def:pub create_flashcards(prompt: str) -> str by llm();

# """Explanation tools."""
# def:pub explain_simple(prompt: str) -> str by llm();
# def:pub explain_step_by_step(prompt: str) -> str by llm();
# def:pub route_explanation(prompt: str) -> str by llm(
#     method="ReAct",
#     tools=([explain_simple, explain_step_by_step])
# );

# """Planner that breaks main utterance into subtasks."""
# def:pub plan_tasks(main_task: str) -> list[TaskPartition] by llm();

# # =========================================================
# # WALKERS (API ENDPOINTS)
# # =========================================================

# walker:pub task_manager {
#     has utterance: str = "";

#     obj __specs__ {
#         static has auth: bool = False;
#     }

#     can start with `root entry {
#         ensure_student_level();

#         subtasks = plan_tasks(self.utterance);

#         results = [];

#         for subtask in subtasks {
#             if subtask.agent_type == RoutingNodes.QUIZ_HANDLING {
#                 # capture quizzes created during this call
#                 before_all = [root -->(`?Quiz)];
#                 before_len = len(before_all);

#                 full_prompt =
#                     f"{subtask.task}\n\n"
#                     f"Here is the study text from the student:\n"
#                     f"{self.utterance}\n\n"
#                     f"Create ONLY multiple-choice questions (MCQs) based on this passage.\n"
#                     f"- If the user asks for N questions, create exactly N questions.\n"
#                     f"==================== STRICT FORMAT RULES ====================\n"
#                     f"- Each question must be in this exact format:\n"
#                     f"Question 1:\n"
#                     f"<question text>\n"
#                     f"1. option one\\n"
#                     f"2. option two\\n"
#                     f"3. option three\\n"
#                     f"4. option four\\n"
#                     f"Then continue with Question 2, Question 3, etc.\n"
#                     f"Do NOT add any extra explanation or commentary.\n"
#                     f"If needed, use web search via tavily_search.\n";


#                 _ = route_and_generate_quiz(full_prompt);

#                 after_all = [root -->(`?Quiz)];
#                 new_quizzes = after_all[before_len:];

#                 results.append({
#                     "type": "quiz",
#                     "task": subtask.task,
#                     "output": format_quizzes(new_quizzes)
#                 });
#             }
#             elif subtask.agent_type == RoutingNodes.SUMMARIZER_HANDLING {
#                 full_prompt =
#                     "Here is the text to summarize:\n"
#                     + self.utterance;

#                 summ = summarize_text(full_prompt);

#                 results.append({
#                     "type": "summary",
#                     "task": subtask.task,
#                     "output": summ
#                 });
#             }
#             elif subtask.agent_type == RoutingNodes.FLASHCARD_HANDLING {
#                 full_prompt =
#                     f"{subtask.task}\n\n"
#                     f"Here is the source text for flashcards:\n"
#                     f"{self.utterance}";


#                 cards = create_flashcards(full_prompt);

#                 results.append({
#                     "type": "flashcards",
#                     "task": subtask.task,
#                     "output": cards
#                 });
#             }
#             elif subtask.agent_type == RoutingNodes.EXPLANATION_HANDLING {
#                 level_node = ensure_student_level();
#                 level_str = level_node.level;

#                 full_prompt =
#                     f"You are an explanation agent with two tools:\n"
#                     f"- explain_simple: short, concise explanation.\n"
#                     f"- explain_step_by_step: detailed explanation broken into steps.\n\n"
#                     f"Student level: {level_str}\n"
#                     f"Use the tools as follows:\n"
#                     f"- If student level is 'beginner', prefer ONLY explain_step_by_step.\n"
#                     f"- If student level is 'intermediate', you may combine both, but include some step-by-step explanation.\n"
#                     f"- If student level is 'advanced', prefer ONLY explain_simple and avoid long step-by-step breakdowns.\n\n"
#                     f"Here is the concept to explain:\n"
#                     f"{self.utterance}";


#                 expl = route_explanation(full_prompt);

#                 results.append({
#                     "type": "explanation",
#                     "task": subtask.task,
#                     "output": expl
#                 });
#             }
#         }

#         report results;
#     }
# }

# walker:pub quiz_answer_walker {
#     has user_answer: str = "";

#     obj __specs__ {
#         static has auth: bool = False;
#     }

#     can start with `root entry {
#         level_node = ensure_student_level();

#         quizzes = [level_node -->(`?Quiz)];
#         if not quizzes {
#             report {"ok": False, "message": "No quiz available. Please generate a quiz first."};
#             return;
#         }

#         q = quizzes[len(quizzes) - 1];

#         user = self.user_answer.strip().lower();
#         correct = q.correct_answer.strip().lower();

#         msg = "";
#         is_correct = False;

#         if user == correct {
#             q.score += 1;
#             msg = "Correct! 🎉";
#             is_correct = True;
#         }
#         else {
#             msg = f"Incorrect. The correct answer is: {q.correct_answer}";
#         }

#         new_level = recompute_level();

#         report {
#             "ok": True,
#             "correct": is_correct,
#             "message": msg,
#             "student_level": new_level
#         };
#     }
# }

# walker:pub levelwalker {
#     obj __specs__ {
#         static has auth: bool = False;
#     }

#     can start with `root entry {
#         lvl = recompute_level();
#         report {"level": lvl};
#     }
# }

# walker:pub explainationwalker {
#     has utterance: str = "";

#     obj __specs__ {
#         static has auth: bool = False;
#     }

#     can start with `root entry {
#         level_node = ensure_student_level();
#         level_str = level_node.level;

#         full_prompt =
#             f"You are an explanation agent with two tools:\n"
#             f"- explain_simple: short, concise explanation.\n"
#             f"- explain_step_by_step: detailed explanation broken into steps.\n\n"
#             f"Student level: {level_str}\n"
#             f"Use the tools as follows:\n"
#             f"- If student level is 'beginner', prefer ONLY explain_step_by_step.\n"
#             f"- If student level is 'intermediate', you may combine both.\n"
#             f"- If student level is 'advanced', prefer ONLY explain_simple.\n\n"
#             f"Here is the concept to explain:\n"
#             f"{self.utterance}";


#         expl = route_explanation(full_prompt);
#         report {"explanation": expl};
#     }
# }

# import from byllm.lib { Model }
# # import from tavily { TavilyClient }
# import os;
# import time;

# glob llm = Model(model_name="gpt-4o-mini");
# # glob tavily_client = TavilyClient(api_key=os.getenv("TAVILY_API_KEY"));

# # ========================================
# # Helper: infer quiz count from user text
# # ========================================
# def infer_quiz_count(text: str) -> int {
#     t = text.lower();

#     # common "one" cases
#     if "one" in t and ("question" in t or "mcq" in t or "quiz" in t) {
#         return 1;
#     }
#     if "single" in t and ("question" in t or "mcq" in t or "quiz" in t) {
#         return 1;
#     }

#     # digit scan (simple, safe)
#     tokens = t.replace("\n", " ").replace(",", " ").split(" ");
#     for tok in tokens {
#         if tok.isdigit() {
#             n = int(tok);
#             if n > 0 and n <= 50 {
#                 return n;
#             }
#         }
#     }

#     # default if user did not specify
#     return 5;
# }

# # ========================================
# # DATA NODES
# # ========================================

# node student_level {
#     has level: str = "beginner",
#         percentage: float = 0.0,
#         full_score: int = 0;

#     can execute with levelwalker entry {
#         print("[Student Level Node Activated]");

#         quizzes = [self -->(`?Quiz)];
#         self.full_score = 0;
#         student_score = 0;

#         for q in quizzes {
#             self.full_score += 1;
#             student_score += q.score;
#         }

#         if self.full_score > 0 {
#             self.percentage = (student_score * 100.0) / self.full_score;
#         }
#         else {
#             self.percentage = 0.0;
#         }

#         if self.percentage >= 80.0 {
#             self.level = "advanced";
#         }
#         elif self.percentage >= 50.0 {
#             self.level = "intermediate";
#         }
#         else {
#             self.level = "beginner";
#         }

#         print(f"Student level updated to: {self.level}");
#         report self.level;
#     }
# }

# node Quiz {
#     has question: str = "",
#         options: str = "",
#         correct_answer: str = "",
#         score: int = 0;
# }

# sem Quiz = "A single multiple-choice question (MCQ).";
# sem Quiz.question = "Text of the MCQ question.";
# sem Quiz.options = "All answer options in a formatted string, typically numbered or lettered.";
# sem Quiz.correct_answer = "The correct option for this MCQ (e.g. 'B' or 'Option 3').";

# # ========================================
# # AGENT NODES (same as your old structure)
# # ========================================

# node QuizHandling {
#     # Tool: store a new quiz question
#     def create_quiz(question: str, options: str, correct_answer: str) -> str {
#         print(f"[Quiz Created]: {question}");

#         created = self ++> Quiz(
#             question=question,
#             options=options,
#             correct_answer=correct_answer,
#             score=0
#         );

#         # created is a list; connect the created Quiz to student_level too
#         level_nodes = [root -->(`?student_level)];
#         if not level_nodes {
#             level_nodes = [root ++> student_level(level="beginner")];
#         }

#         if created and level_nodes {
#             level_nodes[0] ++> created[0];
#         }

#         return "Quiz question added successfully";
#     }

#     def tavily_search(topic: str) -> str {
#         print("Performing Tavily search for topic:", topic);
#         search_results = tavily_client.search(topic, limit=3);
#         snippets = [r["content"] for r in search_results.get("results", []) if "content" in r];
#         return "\n".join(snippets);
#     }

#     def route_and_generate(utterance: str) -> str by llm(
#         method="ReAct",
#         tools=([self.create_quiz, self.tavily_search])
#     );

#     can execute with task_manager entry {
#         print("[QuizHandling Node Activated]");

#         # Force quiz count from user text (prevents planner from forcing 5)
#         n = infer_quiz_count(visitor.utterance);

#         full_prompt = f"""
# {visitor.cur_task.task}

# Here is the study text from the student:
# {visitor.utterance}

# IMPORTANT:
# - Create EXACTLY {n} multiple-choice questions (MCQs).
# - If the user asked for a number, you MUST follow it.

# ==================== STRICT FORMAT RULES ====================
# Each question must be in this exact format:

# Question 1:
# <question text>
# 1. option one
# 2. option two
# 3. option three
# 4. option four

# Then continue with Question 2, Question 3, etc.
# Do NOT add any extra explanation or commentary.
# If needed, use web search via tavily_search.
# """;

#         _ = self.route_and_generate(full_prompt);

#         # collect ALL quiz nodes created so far (or you can keep only newest)
#         quizzes = [self -->(`?Quiz)];
#         if not quizzes {
#             report "";
#             return;
#         }

#         # Show newest batch more reliably: show last n quizzes
#         start_idx = len(quizzes) - n;
#         if start_idx < 0 { start_idx = 0; }
#         newest = quizzes[start_idx:];

#         quiz_text = "";
#         idx = 1;
#         for q in newest {
#             quiz_text += f"{idx}. {q.question}\n\n";
#             quiz_text += f"{q.options}\n\n";
#             idx += 1;
#         }

#         report quiz_text;
#     }
# }

# node SummarizerHandling {
#     def summarize_text(utterance: str) -> str by llm();

#     can execute with task_manager entry {
#         print("[SummarizerHandling Node Activated]");

#         full_prompt = f"""
# Here is the text to summarize:
# {visitor.utterance}
# """;

#         response = self.summarize_text(full_prompt);
#         report response;
#     }
# }

# node ExplanationHandling {
#     def explain_simple(utterance: str) -> str by llm();
#     def explain_step_by_step(utterance: str) -> str by llm();

#     def route_and_run(utterance: str) -> str by llm(
#         method="ReAct",
#         tools=([self.explain_simple, self.explain_step_by_step])
#     );

#     can execute with explainationwalker entry {
#         print("[ExplanationHandling Node Activated]");

#         level_nodes = [root -->(`?student_level)];
#         level_str = "beginner";
#         if level_nodes {
#             level_str = level_nodes[0].level;
#         }

#         full_prompt = f"""
# You are an explanation agent with two tools:
# - explain_simple: short, concise explanation.
# - explain_step_by_step: detailed explanation broken into steps.

# Student level: {level_str}
# Use the tools as follows:
# - If student level is 'beginner', prefer ONLY explain_step_by_step.
# - If student level is 'intermediate', you may combine both, but include some step-by-step explanation.
# - If student level is 'advanced', prefer ONLY explain_simple and avoid long step-by-step breakdowns.

# Here is the concept to explain:
# {visitor.utterance}
# """;

#         response = self.route_and_run(full_prompt);
#         report response;
#     }
# }

# node FlashcardHandling {
#     def create_flashcards(source_text: str) -> str by llm();

#     def route_and_run(utterance: str) -> str by llm(
#         method="ReAct",
#         tools=([self.create_flashcards])
#     );

#     can execute with task_manager entry {
#         print("[FlashcardHandling Node Activated]");

#         full_prompt = f"""
# {visitor.cur_task.task}

# Here is the source text for flashcards:
# {visitor.utterance}
# """;

#         response = self.route_and_run(full_prompt);
#         report response;
#     }
# }

# # ========================================
# # ROUTING METADATA
# # ========================================

# enum RoutingNodes {
#     QUIZ_HANDLING,
#     SUMMARIZER_HANDLING,
#     FLASHCARD_HANDLING,
#     EXPLANATION_HANDLING
# }

# sem RoutingNodes.QUIZ_HANDLING = "Generate and manage multiple-choice quiz questions (MCQs) from the user's request or study material.";
# sem RoutingNodes.SUMMARIZER_HANDLING = "Summarize user-provided text or documents into concise explanations or bullet points.";
# sem RoutingNodes.FLASHCARD_HANDLING = "Create flashcards for study purposes based on the user's input or source text.";
# sem RoutingNodes.EXPLANATION_HANDLING = "Provide simple or step-by-step explanations of concepts as requested by the user.";

# obj TaskPartition {
#     has task: str,
#         agent_type: RoutingNodes;
# }

# sem TaskPartition = "A sub-task derived from the user's main request.";
# sem TaskPartition.task = "Natural language description of this sub-task (e.g. 'create 5 MCQs on photosynthesis').";
# sem TaskPartition.agent_type = "Which specialized agent node should process this sub-task.";

# # ========================================
# # WALKERS (API)
# # ========================================

# walker:pub task_manager {
#     has utterance: str = "",
#         cur_task: TaskPartition = None;

#     obj __specs__ {
#         static has auth: bool = False;
#     }

#     def plan_tasks(main_task: str) -> list[TaskPartition] by llm();

#     can start with `root entry {
#         # Ensure student_level node exists
#         level_nodes = [root -->(`?student_level)];
#         if not level_nodes {
#             root ++> student_level(level="beginner");
#         }

#         subtasks = self.plan_tasks(self.utterance);

#         # Create nodes if missing
#         quiz_nodes = [-->(`?QuizHandling)];
#         if not quiz_nodes { quiz_nodes = [here ++> QuizHandling()]; }

#         sum_nodes = [-->(`?SummarizerHandling)];
#         if not sum_nodes { sum_nodes = [here ++> SummarizerHandling()]; }

#         flash_nodes = [-->(`?FlashcardHandling)];
#         if not flash_nodes { flash_nodes = [here ++> FlashcardHandling()]; }

#         exp_nodes = [-->(`?ExplanationHandling)];
#         if not exp_nodes { exp_nodes = [here ++> ExplanationHandling()]; }

#         # Execute subtasks by visiting correct node
#         for subtask in subtasks {
#             self.cur_task = subtask;

#             if subtask.agent_type == RoutingNodes.QUIZ_HANDLING {
#                 visit quiz_nodes[0];
#             }
#             elif subtask.agent_type == RoutingNodes.SUMMARIZER_HANDLING {
#                 visit sum_nodes[0];
#             }
#             elif subtask.agent_type == RoutingNodes.FLASHCARD_HANDLING {
#                 visit flash_nodes[0];
#             }
#             elif subtask.agent_type == RoutingNodes.EXPLANATION_HANDLING {
#                 visit exp_nodes[0];
#             }
#         }
#     }
# }

# walker:pub explainationwalker {
#     has utterance: str = "";

#     obj __specs__ {
#         static has auth: bool = False;
#     }

#     can start with `root entry {
#         route = [-->(`?ExplanationHandling)];
#         if route {
#             visit route[0];
#         }
#     }
# }

# walker:pub levelwalker {
#     obj __specs__ {
#         static has auth: bool = False;
#     }

#     can start with `root entry {
#         route = [-->(`?student_level)];
#         if route {
#             visit route[0];
#         }
#     }
# }

# walker:pub quiz_answer_walker {
#     has user_answer: str = "";

#     obj __specs__ {
#         static has auth: bool = False;
#     }

#     can start with `root entry {
#         visit [-->(`?QuizHandling)];
#     }

#     can report with QuizHandling entry {
#         quizzes = [-->(`?Quiz)];
#         if not quizzes {
#             report "No quiz available. Please generate a quiz first.";
#             return;
#         }

#         q = quizzes[len(quizzes) - 1];

#         user = self.user_answer.strip().lower();
#         correct = q.correct_answer.strip().lower();

#         msg = "";
#         if user == correct {
#             q.score += 1;
#             msg = "Correct! 🎉";
#         }
#         else {
#             msg = f"Incorrect. The correct answer is: {q.correct_answer}";
#         }

#         report msg;
#     }
# }


# import from byllm.lib { Model }
# # import from tavily { TavilyClient }
# import os;
# import time;

# glob llm = Model(model_name="gpt-4o-mini");
# # glob tavily_client = TavilyClient(api_key=os.getenv("TAVILY_API_KEY"));

# # ========================================
# # Helper: infer quiz count from user text
# # ========================================
# def infer_quiz_count(text: str) -> int {
#     t = text.lower();

#     if "one" in t and ("question" in t or "mcq" in t or "quiz" in t) {
#         return 1;
#     }
#     if "single" in t and ("question" in t or "mcq" in t or "quiz" in t) {
#         return 1;
#     }

#     tokens = t.replace("\n", " ").replace(",", " ").split(" ");
#     for tok in tokens {
#         if tok.isdigit() {
#             n = int(tok);
#             if n > 0 and n <= 50 {
#                 return n;
#             }
#         }
#     }

#     return 5;
# }

# # ========================================
# # DATA NODES
# # ========================================

# node student_level {
#     has level: str = "beginner",
#         percentage: float = 0.0,
#         full_score: int = 0;

#     can execute with levelwalker entry {
#         print("[Student Level Node Activated]");

#         quizzes = [self -->(`?Quiz)];
#         self.full_score = 0;
#         student_score = 0;

#         for q in quizzes {
#             self.full_score += 1;
#             student_score += q.score;
#         }

#         if self.full_score > 0 {
#             self.percentage = (student_score * 100.0) / self.full_score;
#         }
#         else {
#             self.percentage = 0.0;
#         }

#         if self.percentage >= 80.0 {
#             self.level = "advanced";
#         }
#         elif self.percentage >= 50.0 {
#             self.level = "intermediate";
#         }
#         else {
#             self.level = "beginner";
#         }

#         print(f"Student level updated to: {self.level}");
#         report {"level": self.level, "percentage": self.percentage, "full_score": self.full_score};
#     }
# }

# node Quiz {
#     has question: str = "",
#         options: str = "",
#         correct_answer: str = "",
#         score: int = 0;
# }

# sem Quiz = "A single multiple-choice question (MCQ).";
# sem Quiz.question = "Text of the MCQ question.";
# sem Quiz.options = "All answer options in a formatted string, typically numbered or lettered.";
# sem Quiz.correct_answer = "The correct option for this MCQ (e.g. 'B' or 'Option 3').";

# # ========================================
# # ROUTING METADATA
# # ========================================

# enum RoutingNodes {
#     QUIZ_HANDLING,
#     SUMMARIZER_HANDLING,
#     FLASHCARD_HANDLING,
#     EXPLANATION_HANDLING
# }

# sem RoutingNodes.QUIZ_HANDLING = "Generate and manage multiple-choice quiz questions (MCQs) from the user's request or study material.";
# sem RoutingNodes.SUMMARIZER_HANDLING = "Summarize user-provided text or documents into concise explanations or bullet points.";
# sem RoutingNodes.FLASHCARD_HANDLING = "Create flashcards for study purposes based on the user's input or source text.";
# sem RoutingNodes.EXPLANATION_HANDLING = "Provide simple or step-by-step explanations of concepts as requested by the user.";

# obj TaskPartition {
#     has task: str,
#         agent_type: RoutingNodes;
# }

# sem TaskPartition = "A sub-task derived from the user's main request.";
# sem TaskPartition.task = "Natural language description of this sub-task (e.g., 'create 5 MCQs on photosynthesis').";
# sem TaskPartition.agent_type = "Which specialized agent node should process this sub-task.";

# # ========================================
# # AGENT NODES (same graph structure, updated behavior)
# # Each agent appends to visitor.results
# # ========================================

# node QuizHandling {
#     def create_quiz(question: str, options: str, correct_answer: str) -> str {
#         print(f"[Quiz Created]: {question}");

#         created = self ++> Quiz(
#             question=question,
#             options=options,
#             correct_answer=correct_answer,
#             score=0
#         );

#         level_nodes = [root -->(`?student_level)];
#         if not level_nodes {
#             level_nodes = [root ++> student_level(level="beginner")];
#         }

#         if created and level_nodes {
#             level_nodes[0] ++> created[0];
#         }

#         return "Quiz question added successfully";
#     }

#     # If you re-enable Tavily, add it back here.
#     # def tavily_search(topic: str) -> str {
#     #     print("Performing Tavily search for topic:", topic);
#     #     search_results = tavily_client.search(topic, limit=3);
#     #     snippets = [r["content"] for r in search_results.get("results", []) if "content" in r];
#     #     return "\n".join(snippets);
#     # }

#     def route_and_generate(utterance: str) -> str by llm(
#         method="ReAct",
#         tools=([self.create_quiz])
#         # tools=([self.create_quiz, self.tavily_search])  # enable only if tavily_client enabled
#     );

#     can execute with task_manager entry {
#         print("[QuizHandling Node Activated]");

#         n = infer_quiz_count(visitor.utterance);

#         full_prompt = f"""
# {visitor.cur_task.task}

# Here is the study text from the student:
# {visitor.utterance}

# IMPORTANT:
# - Create EXACTLY {n} multiple-choice questions (MCQs).
# - If the user asked for a number, you MUST follow it.

# ==================== STRICT FORMAT RULES ====================
# Question 1:
# <question text>
# 1. option one
# 2. option two
# 3. option three
# 4. option four

# Then continue with Question 2, Question 3, etc.
# Do NOT add any extra explanation or commentary.
# """;

#         _ = self.route_and_generate(full_prompt);

#         quizzes = [self -->(`?Quiz)];
#         quiz_text = "";

#         if quizzes {
#             start_idx = len(quizzes) - n;
#             if start_idx < 0 { start_idx = 0; }
#             newest = quizzes[start_idx:];

#             idx = 1;
#             for q in newest {
#                 quiz_text += f"{idx}. {q.question}\n\n";
#                 quiz_text += f"{q.options}\n\n";
#                 idx += 1;
#             }
#         }

#         visitor.results.append({
#             "type": "quiz",
#             "task": visitor.cur_task.task,
#             "output": quiz_text
#         });
#     }
# }

# node SummarizerHandling {
#     def summarize_text(utterance: str) -> str by llm();

#     can execute with task_manager entry {
#         print("[SummarizerHandling Node Activated]");

#         full_prompt = f"""
# Here is the text to summarize:
# {visitor.utterance}
# """;

#         response = self.summarize_text(full_prompt);

#         visitor.results.append({
#             "type": "summary",
#             "task": visitor.cur_task.task,
#             "output": response
#         });
#     }
# }

# node FlashcardHandling {
#     def create_flashcards(source_text: str) -> str by llm();

#     def route_and_run(utterance: str) -> str by llm(
#         method="ReAct",
#         tools=([self.create_flashcards])
#     );

#     can execute with task_manager entry {
#         print("[FlashcardHandling Node Activated]");

#         full_prompt = f"""
# {visitor.cur_task.task}

# Here is the source text for flashcards:
# {visitor.utterance}
# """;

#         response = self.route_and_run(full_prompt);

#         visitor.results.append({
#             "type": "flashcards",
#             "task": visitor.cur_task.task,
#             "output": response
#         });
#     }
# }

# node ExplanationHandling {
#     def explain_simple(utterance: str) -> str by llm();
#     def explain_step_by_step(utterance: str) -> str by llm();

#     def route_and_run(utterance: str) -> str by llm(
#         method="ReAct",
#         tools=([self.explain_simple, self.explain_step_by_step])
#     );

#     # Called when planner routes explanation
#     can execute with task_manager entry {
#         print("[ExplanationHandling Node Activated - task_manager]");

#         level_nodes = [root -->(`?student_level)];
#         level_str = "beginner";
#         if level_nodes {
#             level_str = level_nodes[0].level;
#         }

#         full_prompt = f"""
# You are an explanation agent with two tools:
# - explain_simple: short, concise explanation.
# - explain_step_by_step: detailed explanation broken into steps.

# Student level: {level_str}
# Use the tools as follows:
# - If student level is 'beginner', prefer ONLY explain_step_by_step.
# - If student level is 'intermediate', you may combine both, but include some step-by-step explanation.
# - If student level is 'advanced', prefer ONLY explain_simple and avoid long step-by-step breakdowns.

# Here is the concept to explain:
# {visitor.utterance}
# """;

#         response = self.route_and_run(full_prompt);

#         visitor.results.append({
#             "type": "explanation",
#             "task": visitor.cur_task.task,
#             "output": response
#         });
#     }

#     # Optional: still allow separate explainationwalker endpoint
#     can execute with explainationwalker entry {
#         print("[ExplanationHandling Node Activated - explainationwalker]");

#         level_nodes = [root -->(`?student_level)];
#         level_str = "beginner";
#         if level_nodes {
#             level_str = level_nodes[0].level;
#         }

#         full_prompt = f"""
# You are an explanation agent with two tools:
# - explain_simple: short, concise explanation.
# - explain_step_by_step: detailed explanation broken into steps.

# Student level: {level_str}
# Use the tools as follows:
# - If student level is 'beginner', prefer ONLY explain_step_by_step.
# - If student level is 'intermediate', you may combine both, but include some step-by-step explanation.
# - If student level is 'advanced', prefer ONLY explain_simple and avoid long step-by-step breakdowns.

# Here is the concept to explain:
# {visitor.utterance}
# """;

#         response = self.route_and_run(full_prompt);
#         report {"type": "explanation", "output": response};
#     }
# }

# # ========================================
# # WALKERS (API)
# # task_manager MUST report visitor.results
# # ========================================

# walker:pub task_manager {
#     has utterance: str = "",
#         cur_task: TaskPartition = None,
#         results: list = [];

#     obj __specs__ {
#         static has auth: bool = False;
#     }

#     def plan_tasks(main_task: str) -> list[TaskPartition] by llm();

#     can start with `root entry {
#         # Ensure student_level exists
#         level_nodes = [root -->(`?student_level)];
#         if not level_nodes {
#             root ++> student_level(level="beginner");
#         }

#         # reset results every request
#         self.results = [];

#         subtasks = self.plan_tasks(self.utterance);
#         print("[Planned Subtasks]:", subtasks);

#         # Ensure agent nodes exist
#         quiz_nodes = [-->(`?QuizHandling)];
#         if not quiz_nodes { quiz_nodes = [here ++> QuizHandling()]; }

#         sum_nodes = [-->(`?SummarizerHandling)];
#         if not sum_nodes { sum_nodes = [here ++> SummarizerHandling()]; }

#         flash_nodes = [-->(`?FlashcardHandling)];
#         if not flash_nodes { flash_nodes = [here ++> FlashcardHandling()]; }

#         exp_nodes = [-->(`?ExplanationHandling)];
#         if not exp_nodes { exp_nodes = [here ++> ExplanationHandling()]; }

#         # Run subtasks
#         for subtask in subtasks {
#             self.cur_task = subtask;

#             if subtask.agent_type == RoutingNodes.QUIZ_HANDLING {
#                 visit quiz_nodes[0];
#             }
#             elif subtask.agent_type == RoutingNodes.SUMMARIZER_HANDLING {
#                 visit sum_nodes[0];
#             }
#             elif subtask.agent_type == RoutingNodes.FLASHCARD_HANDLING {
#                 visit flash_nodes[0];
#             }
#             elif subtask.agent_type == RoutingNodes.EXPLANATION_HANDLING {
#                 visit exp_nodes[0];
#             }
#         }

#         # IMPORTANT: report as an object, not a raw list
#         report {
#             "ok": True,
#             "results": self.results
#         };
#     }
# }


# walker:pub explainationwalker {
#     has utterance: str = "";

#     obj __specs__ {
#         static has auth: bool = False;
#     }

#     can start with `root entry {
#         route = [-->(`?ExplanationHandling)];
#         if route {
#             visit route[0];
#         }
#     }
# }

# walker:pub levelwalker {
#     obj __specs__ {
#         static has auth: bool = False;
#     }

#     can start with `root entry {
#         route = [-->(`?student_level)];
#         if route {
#             visit route[0];
#         }
#     }
# }

# walker:pub quiz_answer_walker {
#     has user_answer: str = "";

#     obj __specs__ {
#         static has auth: bool = False;
#     }

#     can start with `root entry {
#         level_nodes = [root -->(`?student_level)];
#         if not level_nodes {
#             root ++> student_level(level="beginner");
#             level_nodes = [root -->(`?student_level)];
#         }

#         quizzes = [level_nodes[0] -->(`?Quiz)];
#         if not quizzes {
#             report {"ok": False, "message": "No quiz available. Please generate a quiz first."};
#             return;
#         }

#         q = quizzes[len(quizzes) - 1];

#         user = self.user_answer.strip().lower();
#         correct = q.correct_answer.strip().lower();

#         is_correct = False;
#         msg = "";

#         if user == correct {
#             q.score += 1;
#             is_correct = True;
#             msg = "Correct! 🎉";
#         }
#         else {
#             msg = f"Incorrect. The correct answer is: {q.correct_answer}";
#         }

#         # recompute level
#         lvl = root spawn levelwalker();

#         # lvl.reports[0] will be {"level": ...}
#         student_lvl = "";
#         if lvl and lvl.reports and lvl.reports.length > 0 {
#             rep = lvl.reports[lvl.reports.length - 1];
#             if rep and rep.level { student_lvl = rep.level; }
#         }

#         report {"ok": True, "correct": is_correct, "message": msg, "student_level": student_lvl};
#     }
# }


import from byllm.lib { Model }
import os;
import time;

glob llm = Model(model_name="gpt-4o-mini");


def infer_quiz_count(text: str) -> int {
    t = text.lower();

    if "one" in t and ("question" in t or "mcq" in t or "quiz" in t) { return 1; }
    if "single" in t and ("question" in t or "mcq" in t or "quiz" in t) { return 1; }

    tokens = t.replace("\n", " ").replace(",", " ").split(" ");
    for tok in tokens {
        if tok.isdigit() {
            n = int(tok);
            if n > 0 and n <= 50 { return n; }
        }
    }

    return 5;
}



node student_level {
    has level: str = "beginner",
        percentage: float = 0.0,
        full_score: int = 0;

    can execute with levelwalker entry {
        quizzes = [self -->(`?Quiz)];
        self.full_score = 0;
        student_score = 0;

        for q in quizzes {
            self.full_score += 1;
            student_score += q.score;
        }

        if self.full_score > 0 {
            self.percentage = (student_score * 100.0) / self.full_score;
        } else {
            self.percentage = 0.0;
        }

        if self.percentage >= 80.0 { self.level = "advanced"; }
        elif self.percentage >= 50.0 { self.level = "intermediate"; }
        else { self.level = "beginner"; }

        report {"level": self.level, "percentage": self.percentage, "full_score": self.full_score};
    }
}

node Quiz {
    has question: str = "",
        options: str = "",
        correct_answer: str = "",
        score: int = 0;
}



node QuizHandling {
    def create_quiz(question: str, options: str, correct_answer: str) -> str {
        created = self ++> Quiz(
            question=question,
            options=options,
            correct_answer=correct_answer,
            score=0
        );

        level_nodes = [root -->(`?student_level)];
        if not level_nodes {
            level_nodes = [root ++> student_level(level="beginner")];
        }

        if created and level_nodes { level_nodes[0] ++> created[0]; }

        return "ok";
    }

    def route_and_generate(utterance: str) -> str by llm(
        method="ReAct",
        tools=([self.create_quiz])
    );

    can execute with task_manager entry {
        n = infer_quiz_count(visitor.utterance);

        full_prompt = f"""
{visitor.cur_task.task}

Here is the study text from the student:
{visitor.utterance}

IMPORTANT:
- Create EXACTLY {n} multiple-choice questions (MCQs).
- Use the tool create_quiz() for each question.
- correct_answer MUST be one of: "1" or "2" or "3" or "4"

FORMAT:
Question 1:
<question>
1. ...
2. ...
3. ...
4. ...
""";

        _ = self.route_and_generate(full_prompt);

        quizzes = [self -->(`?Quiz)];
        if not quizzes {
            visitor.results.append({"type":"quiz","task":visitor.cur_task.task,"output":""});
            return;
        }

        start_idx = len(quizzes) - n;
        if start_idx < 0 { start_idx = 0; }
        newest = quizzes[start_idx:];

        quiz_text = "";
        idx = 1;
        for q in newest {
            quiz_text += f"{idx}. {q.question}\n\n";
            quiz_text += f"{q.options}\n\n";
            idx += 1;
        }

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
        full_prompt = "Here is the text to summarize:\n" + visitor.utterance;
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
        level_nodes = [root -->(`?student_level)];
        level_str = "beginner";
        if level_nodes { level_str = level_nodes[0].level; }

        full_prompt =
            "Student level: " + level_str + "\n" +
            "Explain the following:\n" +
            visitor.utterance;

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

    can execute with task_manager entry {
        full_prompt = visitor.cur_task.task + "\n\nHere is the source text:\n" + visitor.utterance;
        response = self.create_flashcards(full_prompt);

        visitor.results.append({
            "type": "flashcards",
            "task": visitor.cur_task.task,
            "output": response
        });
    }
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



walker:pub task_manager {
    has utterance: str = "",
        cur_task: TaskPartition = None,
        results: list = [];

    obj __specs__ {
        static has auth: bool = False;
    }

    def plan_tasks(main_task: str) -> list[TaskPartition] by llm();

    can start with `root entry {
        level_nodes = [root -->(`?student_level)];
        if not level_nodes { root ++> student_level(level="beginner"); }

        self.results = [];

        subtasks = self.plan_tasks(self.utterance);

        quiz_nodes = [-->(`?QuizHandling)];
        if not quiz_nodes { quiz_nodes = [here ++> QuizHandling()]; }

        sum_nodes = [-->(`?SummarizerHandling)];
        if not sum_nodes { sum_nodes = [here ++> SummarizerHandling()]; }

        flash_nodes = [-->(`?FlashcardHandling)];
        if not flash_nodes { flash_nodes = [here ++> FlashcardHandling()]; }

        exp_nodes = [-->(`?ExplanationHandling)];
        if not exp_nodes { exp_nodes = [here ++> ExplanationHandling()]; }

        for subtask in subtasks {
            self.cur_task = subtask;

            if subtask.agent_type == RoutingNodes.QUIZ_HANDLING { visit quiz_nodes[0]; }
            elif subtask.agent_type == RoutingNodes.SUMMARIZER_HANDLING { visit sum_nodes[0]; }
            elif subtask.agent_type == RoutingNodes.FLASHCARD_HANDLING { visit flash_nodes[0]; }
            elif subtask.agent_type == RoutingNodes.EXPLANATION_HANDLING { visit exp_nodes[0]; }
        }

        report {"ok": True, "results": self.results};
    }
}

walker:pub levelwalker {
    obj __specs__ { static has auth: bool = False; }

    can start with `root entry {
        route = [-->(`?student_level)];
        if route { visit route[0]; }
        else { report {"level":"beginner","percentage":0.0,"full_score":0}; }
    }
}

walker:pub quiz_answer_walker {
    has user_answer: str = "";

    obj __specs__ { static has auth: bool = False; }

    can start with `root entry {
        quizzes = [-->(`?Quiz)];
        if not quizzes {
            report {"ok": False, "message": "No quiz available. Generate a quiz first."};
            return;
        }

        q = quizzes[len(quizzes) - 1];

        user = self.user_answer.strip().lower();
        correct = q.correct_answer.strip().lower();

        if user == correct {
            q.score += 1;
            report {"ok": True, "correct": True, "message": "Correct! 🎉"};
        } else {
            report {"ok": True, "correct": False, "message": f"Incorrect. Correct answer: {q.correct_answer}"};
        }
    }
}
