CREATE TABLE TASK
(
    ID                 TEXT      NOT NULL PRIMARY KEY,
    PRIORITY           INTEGER   NOT NULL,
    GROUP_ID           TEXT      NULL,
    CLASS              TEXT      NOT NULL,
    SIMPLE_TYPE        TEXT      NOT NULL,
    PAYLOAD            TEXT      NOT NULL,
    OWNER              TEXT      NULL,
    CREATED_DATE       TIMESTAMP NOT NULL DEFAULT NOW(),
    LAST_MODIFIED_DATE TIMESTAMP NOT NULL DEFAULT NOW()
);

CREATE INDEX idx__tasks__owner_group_id
    ON TASK (OWNER, GROUP_ID);
