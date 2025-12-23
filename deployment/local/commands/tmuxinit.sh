#!/usr/bin/zsh

project=museumsportal

tmux new-session -d -s $project
tmux split-window -h -l 50% -t $project
tmux split-window -v -l 67% -t $project
tmux split-window -v -l 50% -t $project

tmux send-keys -t $project:0.1 "python manage.py runserver --settings=$project.settings.local_iraklis" C-m
tmux send-keys -t $project:0.2 "cd $project/site_static/site/mp-distribution;clear" C-m
tmux send-keys -t $project:0.3 "cd deployment/ansible;clear" C-m

tmux attach-session -t $project