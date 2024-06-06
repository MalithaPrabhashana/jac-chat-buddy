import:py from jaclang.core.llms, Anthropic;
import:py random;

glob llm = Anthropic(model_name="claude-3-sonnet-20240229");


'''
User node has user_name attribute.
'''
node user {
    has user_name:str = "user";
}

'''
This is the session of a chat.
'''
node session {
    has session_id:str = "100";
    has user_data:dict = {};
    has todo_list:list = [];
}

'''
This contains user data.
'''
node data {
    has user_data:dict = {
        "age": 0,
        "pressure": (0,0),
        "married": False

    };
}


'''
List of things to do by the user.
'''
node todo {
    has todo_list:list = [];
}



# ==========================================================

'''
Walker for creating the graph.
'''
walker create_graph {
    has user_data:dict = {};
    has todo_list:list = [];

    can generate_graph with `root entry;
}


'''
Walker for chatting with the user.
'''
walker chat {
    can create_session with user entry;
    can create_chat with session entry;
}


'''
Query walker actives on the session node.
'''
walker query {
    has query:str = "";
    has task_type: str = "";
    has user_session_id:str = "";
    has session_chat_history:list = [];
    has user_data:dict = {};
    has todo_list:list = [];

    can init_query_engine with session entry;
}


'''
Router node routes the session node to the appropriate chat.
'''
node router {
    can route with query entry;
}

node rag_chat {
    can route_rag with query entry {
        print("Running RAG");
    }
}

node user_qa_chat {
    can route_user_qa with query entry {
        # print("Running User_QA");

        while True {
            entered_query = input("Enter the query: ");
            here.query:str = entered_query;

            if entered_query == 'exit' {
                disengage;
            }

            response = self.chat_user_qa_with_llm(here.user_data, here.session_chat_history, here.query);

            current_chat: dict = {
                'query': entered_query,
                'answer': response
            };

            here.session_chat_history.append(current_chat);

            print("Answer: ", response);
        }
    }

    can 'Give the response based on the use data'
    chat_user_qa_with_llm(user_data: 'This is the personal data of the user': dict,
                          chat_history: 'This is chat history with the user. The latest chats have the highest index in the list.': list,
                          query: 'This is the question that user asks based on the user data': str) -> 'response': str by llm();
}


node user_todo_chat {
    can route_user_todo with query entry {
        # print("Running TODO");

        while True {
            entered_query = input("Enter the query: ");
            here.query:str = entered_query;

            if entered_query == 'exit' {
                disengage;
            }

            response = self.chat_todo_with_llm(here.todo_list, here.user_data, here.session_chat_history, entered_query);

            current_chat: dict = {
                'query': entered_query,
                'answer': response
            };

            here.session_chat_history.append(current_chat);

            print("Answer: ", response);
        }
    }

    can 'You are a health Assistant. So give the response based on the my TODOs'
    chat_todo_with_llm(todo_list: 'This is the todo list with the health status of the user' : list, 
                  user_data: 'This is the personal data of the user': dict,
                  chat_history: 'This is chat history with the user. The latest chats have the highest index in the list.': list,
                  query: 'This is the thing that user is going to do in the future': str) -> 'response': str by llm();
}


:node:router:can:route {
    path = here.task_type;

    if path == "RAG" {
        visit [-->](`?rag_chat);
    } elif path == "QA" {
        visit [-->](`?user_qa_chat);
    } elif path == "TODO" {
        visit [-->](`?user_todo_chat);
    }
}


# ==========================================================

:walker:create_graph:can:generate_graph {
    end = here;
    end ++> (end := user());
    end ++> data(user_data = self.user_data);
    end ++> todo(todo_list = self.todo_list);
    chat() spawn [-->](`?user)[0];
}


:walker:chat:can:create_session {
    data_node = [-->](`?data)[0];
    todo_node = [-->](`?todo)[0];
    new_session_id = str(random.randint(0,100));

    n = here ++> session(   session_id = new_session_id,
                            user_data = data_node.user_data,
                            todo_list = todo_node.todo_list
                        );
    visit n;
}


:walker:chat:can:create_chat {
    query() spawn here;
}


:walker:query:can:init_query_engine {
    path = input("Enter the route: ");

    self.task_type:str = path;
    self.user_data:dict = here.user_data;
    self.todo_list:list = here.todo_list;

    end = here;
    end ++> (end := router());
    end ++> rag_chat();
    end ++> user_qa_chat();
    end ++> user_todo_chat();

    visit [-->];
}


with entry {
    create_graph (
            user_data = { "age": 20,
                        "Pressure": (120, 80),
                        "Married": False
                        },
            todo_list = ["Do heart surgery",
                        "Buy Bread",
                        "Have pizza for dinner"
                        ]
                ) spawn root;
}