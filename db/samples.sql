SELECT count(*), tid
FROM threads_responses
WHERE (
        fid = 240
        and last_post_date > '2022-10-02 09:09:16.666556+0000'
    )
group by tid
