include RbCommonHelper

class RbEpicboardsController < RbApplicationController
  unloadable

  def show
    stories = RbStory.stories_open(@project)
    @epics = RbEpic.epics_open(@project)
    puts "STORIES on epic board #{stories.map{|s|s.subject}}"    
    puts "EPICS on epic board #{@epics.map{|s|s.subject}}"    
    @story_ids    = stories.map{|s| s.id}

    @settings = Backlogs.settings

    ## determine status columns to show
    tracker = Tracker.find_by_id(RbStory.trackers[0])
    statuses = tracker.issue_statuses
    # disable columns by default
    if User.current.admin? || stories.length == 0
      puts "User is admin"
      @statuses = statuses
    else
      puts "User is not admin"
      enabled = {}
      statuses.each{|s| enabled[s.id] = false}
      # enable all statuses held by current tasks, regardless of whether the current user has access
      stories.each {|task| enabled[task.status_id] = true }
      enabled[IssueStatus.default.id] = true if stories.length == 0 #enable at least one if there are no stories

      roles = User.current.roles_for_project(@project)
      #@transitions = {}
      statuses.each {|status|

        # enable all statuses the current user can reach from any task status
        [false, true].each {|creator|
          [false, true].each {|assignee|

            allowed = status.new_statuses_allowed_to(roles, tracker, creator, assignee).collect{|s| s.id}
            #@transitions["c#{creator ? 'y' : 'n'}a#{assignee ? 'y' : 'n'}"] = allowed
            allowed.each{|s| enabled[s] = true}
          }
        }
      }
      @statuses = statuses.select{|s| enabled[s.id]}
    end
    puts "STATUSES on epic board #{@statuses.map{|s|s.name}}"

    if stories.size == 0
      @last_updated = nil
    else
      @last_updated = RbStory.find(:first,
                        :conditions => ['tracker_id in (?)', RbStory.trackers],
                        :order      => "updated_on DESC")
    end

    respond_to do |format|
      format.html { render :layout => "rb" }
    end
  end

end