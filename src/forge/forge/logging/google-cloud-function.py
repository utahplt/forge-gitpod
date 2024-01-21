import os
import sqlalchemy
import json

def access_secret_version(project_id, secret_id, version_id):
    """
    Access the payload for the given secret version if one exists. The version
    can be a version number as a string (e.g. "5") or an alias (e.g. "latest").
    """

    # Import the Secret Manager client library.
    from google.cloud import secretmanager

    # Create the Secret Manager client.
    client = secretmanager.SecretManagerServiceClient()

    # Build the resource name of the secret version.
    name = client.secret_version_path(project_id, secret_id, version_id)

    # Access the secret version.
    response = client.access_secret_version(name)

    # Print the secret payload.
    #
    # WARNING: Do not print the secret in a production environment - this
    # snippet is showing how to access the secret material.
    payload = response.payload.data.decode('UTF-8')
    return payload

db_user = access_secret_version("pyret-examples", "FORGE_LOGGING_DB_USER", "latest")
db_pass = access_secret_version("pyret-examples", "FORGE_LOGGING_DB_PASS", "latest")
db_name = os.environ["DB_NAME"]
db_socket_dir = os.environ.get("DB_SOCKET_DIR", "/cloudsql")
cloud_sql_connection_name = os.environ["CLOUD_SQL_CONNECTION_NAME"]

engine = sqlalchemy.create_engine(
    # Equivalent URL:
    # postgres+pg8000://<db_user>:<db_pass>@/<db_name>
    #                         ?unix_sock=<socket_path>/<cloud_sql_instance_name>/.s.PGSQL.5432
    sqlalchemy.engine.url.URL(
        drivername="postgres+pg8000",
        username=db_user,  # e.g. "my-database-user"
        password=db_pass,  # e.g. "my-database-password"
        database=db_name,  # e.g. "my-database-name"
        query={
            "unix_sock": "{}/{}/.s.PGSQL.5432".format(
                db_socket_dir,  # e.g. "/cloudsql"
                cloud_sql_connection_name)  # i.e "<PROJECT-NAME>:<INSTANCE-REGION>:<INSTANCE-NAME>"
        }
    ),
    # ... Specify additional properties here.
)

print(f"Logging engine: {engine}")
with engine.connect() as connection:
    print(f"Logging engine.connect(): {connection}")

def handle(request):
    # with engine.connect() as connection:
    #     result = connection.execute("SELECT * FROM submission")
    #     ret = ""
    #     for row in result:
    #         ret += f"User {row['username']} says {row['contents']}!\n"
    # print(f"Logging: {ret}")
    
    try:
        data = json.loads(request.data)
    except Exception as err:
        print(f"ERROR (in parsing request json): {err}")
        return ("Failed to parse data.", 400, {})

    try:
        executions = []
        current_execution = None
        for log in data:
            log_type = log["log-type"]
            if log_type == "execution":
                current_execution = load_execution(log)
                executions.append(current_execution)
            elif log_type == "run":
                load_run(log, current_execution)
            elif log_type == "instance":
                load_instance(log, current_execution)
            elif log_type == "test":
                load_test(log, current_execution)
            elif log_type == "check-ex-spec":
                load_check_ex_spec(log, current_execution)
            elif log_type == "error":
                load_error(log, current_execution)
            elif log_type == "notification":
                load_notification(log, current_execution)
            else:
                raise Exception("Unrecognized log type.")
    except Exception as err:
        print(f"ERROR (in translating json): {err}")
        return add_failure_to_database(data, f"ERROR (in translating json): {err}")

    try:
        for execution in executions:
            add_to_database(execution)
    except Exception as err:
        print(f"ERROR (in writing to database): {err}")
        return add_failure_to_database(data, f"ERROR (in writing to database): {err}")

    
    return ("Successfully logged data.", 201, {})

def fix(filename):
    parts = filename.split(".")
    real_name = f"{parts[0]}.{parts[1]}"
    fixed_hash = str(hash(".".join(parts[2:])))
    return f"{real_name}.{fixed_hash}"

# fix all filenames in a list or dict by mutating the input
def fix_filenames(data):
    if isinstance(data, list):
        for log in data:
            fix_filenames(log)
    elif isinstance(data, dict) and "filename" in data:
        data["filename"] = fix(data["filename"])
    return

"""
input:
    {
        "log-type": "execution",
        "user": "<student>@cs.brown.edu",
        "filename": "/User/<username>/Documents/cs1950y/forge1.rkt",
        "project": "forge1",
        "time": 12345987023458,
        "raw": "#lang forge/core\n...",
        "mode": "forge/core",
    }
"""
def load_execution(log):
    return {
            "user": log["user"],
            "filename": fix(log["filename"]),
            "project": log["project"],
            "time": log["time"],
            "raw": log["raw"],
            "mode": log["mode"],
            "runs": [],
            "tests": [],
            "check-ex-spec": None,
            "error": None,
            "notifications": []
        }

"""
input:
    {
        "log-type": "run",
        "raw": "(run my-run #:preds [...] ...)",
        "run-id": 0,
        "spec": {
                "sigs": ["A", "B"],
                "relations": ["r"],
                "predicates": ["..."],
                "bounds": ["..."],
            },
    }
"""
def load_run(log, execution):
    execution["runs"].append({
            "raw": log["raw"],
            "spec": log["spec"],
            "result": "unknown"
        })

"""
input:
    {
        "log-type": "instance",
        "run-id": 0,
        "label": "sat",
        "instancs": [...]
    }
    {
        "log-type": "instance",
        "run-id": 0,
        "label": "no-more-instances",
    }
    {
        "log-type": "instance",
        "run-id": 1,
        "label": "unsat",
        "core": "...",
    }
"""
def load_instance(log, execution):
    run = execution["runs"][log["run-id"]]
    label = log["label"]
    if label == "sat":
        run["result"] = "sat"
        if "instances" not in run:
            run["instances"] = []
        run["instances"].append({
                "instances": log["instances"],
                "notifications": []
            })
        run["no-more-instances"] = False
    elif label == "no-more-instances":
        run["no-more-instances"] = True
    elif label == "unsat":
        run["result"] = "unsat"
        run["core"] = log["core"]

"""
input:
    {
        "log-type": "test",
        "raw": "(test my-test #:preds [...] ...)",
        "expected": "sat",
        "passed": true,
        "spec": {
                "sigs": ["A", "B"],
                "relations": ["r"],
                "predicates": ["..."],
                "bounds": ["..."],
            },
    }
"""
def load_test(log, execution):
    execution["tests"].append({
            "raw": log["raw"],
            "spec": log["spec"],
            "expected": log["expected"],
            "passed": log["passed"],
            "data": log["data"] if log["data"] else None
        })

def load_check_ex_spec(log, execution):
    execution["check-ex-spec"] = {
        "wheat-results": log["wheat-results"],
        "chaff-results": log["chaff-results"]
    }

def load_error(log, execution):
    execution["error"] = log["message"]

def load_notification(log, execution):
    execution["runs"][-1]["instances"][-1]["notifications"].append({
            "message": log["message"],
            "data": log["data"] if log["data"] else None,
            "time": log["time"]
        })

def get_column(result_proxy, column):
    tuples = result_proxy.fetchall()
    return [tup[column] for tup in tuples]

"""
input:
    {
        "user": log["user"],
        "filename": log["filename"],
        "project": log["project"],
        "time": log["time"],
        "raw": log["raw"],
        "mode": log["mode"],
        "runs": [],
        "tests": []
    }
"""
def add_to_database(execution):
    def get_user_id(connection, user_name):
        command = sqlalchemy.text("""
            SELECT id 
            FROM students 
            WHERE email=:email
            """)
        user_id_list = get_column(connection.execute(command, email=user_name), 'id')

        if len(user_id_list) == 0:
            command = sqlalchemy.text("""
                INSERT INTO students(email) 
                VALUES (:email)
                RETURNING id
                """)
            return get_column(connection.execute(command, email=user_name), 'id')[0]
        elif len(user_id_list) == 1:
            return user_id_list[0]
        else:
            raise Exception("Found multiple users with that email.")


    def get_project_id(connection, project_name):
        command = sqlalchemy.text("""
            SELECT id 
            FROM projects 
            WHERE name=:name
            """)
        project_id_list = get_column(connection.execute(command, name=project_name), 'id')

        if len(project_id_list) == 0:
            command = sqlalchemy.text("""
                INSERT INTO projects(name) 
                VALUES (:name)
                RETURNING id
                """)
            return get_column(connection.execute(command, name=project_name), 'id')[0]
        elif len(project_id_list) == 1:
            return project_id_list[0]
        else:
            raise Exception("Found multiple projects with that name.")


    def get_file_id(connection, file_name, raw, user_id, project_id):
        command = sqlalchemy.text("""
            SELECT id
            FROM files 
            WHERE name=:name
            AND   student_id=:student_id
            AND   project_id=:project_id
            """)
        file_id_list = get_column(connection.execute(
            command, 
            name=file_name,
            student_id=user_id,
            project_id=project_id), 'id')

        if len(file_id_list) == 0:
            command = sqlalchemy.text("""
                INSERT INTO files(name, student_id, project_id, current_contents) 
                VALUES (:name, :student_id, :project_id, :current_contents)
                RETURNING id, current_contents
                """)
            return get_column(connection.execute(
                command, 
                name=file_name,
                student_id=user_id,
                project_id=project_id,
                current_contents=raw), 'id')[0]

        elif len(file_id_list) == 1:
            return file_id_list[0]
        else:
            raise Exception("Found multiple files with that name for given user and project.")

    def get_execution_id(connection, time, mode, contents, file_id, error):
        command = sqlalchemy.text("""
            INSERT INTO executions(file_id, snapshot, time, mode, error)
            VALUES (:file_id, :snapshot, :time, :mode, :error)
            RETURNING id
            """)
        result = connection.execute(
            command,
            file_id=file_id,
            snapshot=contents,
            time=time,
            mode=mode,
            error=error)
        return get_column(result, 'id')[0]

    def add_runs(connection, runs, execution_id):
        for run in runs:
            command = sqlalchemy.text("""
                INSERT INTO commands(execution_id, command)
                VALUES (:execution_id, :command)
                RETURNING id
                """)
            command_id = get_column(connection.execute(
                command,
                execution_id=execution_id,
                command=run["raw"]), 'id')[0]

            command = sqlalchemy.text("""
                INSERT INTO runs(command_id, result)
                VALUES (:command_id, :result)
                """)
            connection.execute(
                command,
                command_id=command_id,
                result=run["result"])

            if run["result"] == "core":
                command = sqlalchemy.text("""
                    INSERT INTO cores(command_id, core)
                    VALUES (:command_id, :core)
                    """)
                connection.execute(
                    command,
                    command_id=command_id,
                    core=run["core"])
            elif run["result"] == "sat":
                for instance in run["instances"]:
                    command = sqlalchemy.text("""
                        INSERT INTO instances(command_id, model)
                        VALUES (:command_id, :model)
                        RETURNING id
                        """)
                    instance_id = get_column(connection.execute(
                        command,
                        command_id=command_id,
                        model=json.dumps(instance["instances"])), 'id')[0]
                    for notification in instance["notifications"]:
                        command = sqlalchemy.text("""
                            INSERT INTO notifications(instance_id, message, data, time)
                            VALUES (:instance_id, :message, :data, :time)
                            """)
                        connection.execute(
                            command,
                            instance_id=instance_id,
                            message=notification["message"],
                            data=notification["data"],
                            time=notification["time"])

    def add_tests(connection, tests, execution_id):
        for test in tests:
            command = sqlalchemy.text("""
                INSERT INTO commands(execution_id, command)
                VALUES (:execution_id, :command)
                RETURNING id
                """)
            command_id = get_column(connection.execute(
                command,
                execution_id=execution_id,
                command=test["raw"]), 'id')[0]

            command = sqlalchemy.text("""
                INSERT INTO tests(command_id, expected, passed, data)
                VALUES (:command_id, :expected, :passed, :data)
                """)
            connection.execute(
                command,
                command_id=command_id,
                expected=test["expected"],
                passed=test["passed"],
                data=json.dumps(test["data"]))

    def add_check_ex_spec(connection, results, execution_id):
        if results:
            command = sqlalchemy.text("""
                INSERT INTO check_ex_spec(execution_id, results)
                VALUES (:execution_id, :results)
                """)
            connection.execute(
                command,
                execution_id=execution_id,
                results=json.dumps(results))

    with engine.begin() as connection:
        user_id = get_user_id(connection, execution["user"])
        project_id = \
            get_project_id(
                connection, 
                execution["project"])
        file_id = \
            get_file_id(
                connection, 
                execution["filename"], 
                execution["raw"], 
                user_id, 
                project_id)
        execution_id = \
            get_execution_id(
                connection, 
                execution["time"], 
                execution["mode"], 
                execution["raw"], 
                file_id,
                execution["error"])
        add_runs(connection, execution["runs"], execution_id)
        add_tests(connection, execution["tests"], execution_id)
        add_check_ex_spec(connection, execution["check-ex-spec"], execution_id)

def add_failure_to_database(log, error):
    try:
        fix_filenames(log)
        with engine.begin() as connection:
            command = sqlalchemy.text("""
                INSERT INTO failed_logs(log, error)
                VALUES (:log, :error)
                """)
            connection.execute(
                command,
                log=json.dumps(log),
                error=error)
        return ("There was an error, but logs were saved to database.", 201, {})
    except Exception as err:
        print(f"Error in logging failed log: {err}")
        print(f"Log: {log}")
        print(f"Original error: {error}")
        return ("Something went wrong.", 400, {})



