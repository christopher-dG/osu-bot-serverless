module Reddit

using PyCall

export login, posts, mentions, reply

"""
    login() -> Void

Log in to Reddit and bind the global bot and subreddit variables.
"""
function login()
    @pyimport praw
    global bot = praw.Reddit(;
        user_agent=ENV["REDDIT_USER_AGENT"],
        client_id=ENV["REDDIT_CLIENT_ID"],
        client_secret=ENV["REDDIT_CLIENT_SECRET"],
        username=ENV["REDDIT_USERNAME"],
        password=ENV["REDDIT_PASSWORD"],
    )
    global subreddit = bot[:subreddit](ENV["REDDIT_SUBREDDIT"])
    log("Logged into Reddit")
    return nothing
end

"""
    posts(channel::Channel) -> Void

Put new posts from the global subreddit into `channel` as they arrive. `praw` has a
streaming method built in, but new posts are picked up at slow/inconsistent intervals.
This function does not return, so wrap it in `@async`.
"""
function posts(channel::Channel)
    ids = String[]  # Ordered [oldest, ..., newest].
    while true
        for post in reverse(collect(subreddit[:new]()))  # Oldest posts first.
            if !in(post[:id], ids)
                push!(ids, post[:id])
                length(ids) > 100 && shift!(ids)  # Remove the oldest entry.
                put!(channel, post)
            end
        end
        gc()  # Shouldn't be necessary; this is a PyCall bug (#436).
        sleep(10)
    end
end

"""
    mentions(channel::Channel) -> Void

Similar to `posts` but for comment mentions.
"""
function mentions(channel::Channel)
    ids = String[]
    while true
        for comment in reverse(collect(bot[:inbox][:mentions](; limit=50)))
            if !in(comment[:id], ids)
                push!(ids, comment[:id])
                length(ids) > 50 && shift!(ids)
                put!(channel, comment)
            end
        end
        gc()
        sleep(10)
    end
end

"""
    reply(obj::PyObject, comment::AbstractString; sticky::Bool=false) -> Void

Reply to a post or comment with `comment`, then upvote and save it.
"""
function reply(obj::PyObject, comment::AbstractString; sticky::Bool=false)
    comment = obj[:reply](comment)
    sticky && comment[:mod][:distinguish](; sticky=true)
    obj[:save]()
    obj[:upvote]()
end

log(msg) = (info("$(basename(@__FILE__)): $msg"); true)

end
