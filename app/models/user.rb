require 'securerandom'

class User < ActiveRecord::Base

	has_many :scripts
	has_many :listable_scripts, -> {
		# copy from Script.listable. Is this the most elegant way to do this?
		o = nil
		Script.listable.where_values.each{|wv| o = o.nil? ? where(wv) : o.where(wv)}
		o
	}, :class_name => 'Script'

	#this results in a cartesian join when included with the scripts relation
	#has_many :discussions, through: :scripts

	has_and_belongs_to_many :roles

	has_many :identities

	has_many :script_sets

	belongs_to :locale

	# Include default devise modules. Others available are:
	# :confirmable, :lockable, :timeoutable and :omniauthable
	devise :database_authenticatable, :registerable, :recoverable, :rememberable, :trackable, :validatable

	validates_presence_of :name, :profile_markup
	validates_uniqueness_of :name
	validates_length_of :profile, :maximum => 10000
	validates_inclusion_of :profile_markup, :in => ['html', 'markdown']

	strip_attributes

	def discussions_on_scripts_written
		scripts.map {|s| s.discussions}.flatten.sort{|a,b| a.updated <=> b.updated }
	end

	def slugify(name)
		# take out swears
		r = name.downcase.gsub(/motherfucking|motherfucker|fucking|fucker|fucks|fuck|shitty|shits|shit|niggers|nigger|cunts|cunt/, '')
		# multiple non-alphas into one
		r.gsub!(/([^[:alnum:]])[^[:alnum:]]+/) {|s| $1}
		# leading non-alphas
		r.gsub!(/^[^[:alnum:]]+/, '')
		# trailing non-alphas
		r.gsub!(/[^[:alnum:]]+$/, '')
		# non-alphas into dashes
		r.gsub!(/[^[:alnum:]]/, '-')
		# use "script" if we don't have something suitable
		r = 'user' if r.empty?
		return r
	end

	def to_param
		"#{id}-#{slugify(name)}"
	end

	def moderator?
		!roles.select { |role| role.name == 'Moderator' }.empty?
	end

	def administrator?
		!roles.select { |role| role.name == 'Moderator' }.empty?
	end

	def generate_webhook_secret
		self.webhook_secret = SecureRandom.hex(64)
	end

	def pretty_signin_methods
		return self.identity_providers_used.map{|p| Identity.pretty_provider(p)}
	end

	def identity_providers_used
		return self.identities.map{|i| i.provider}.uniq
	end

	def favorite_script_set
		return ScriptSet.where(:favorite => true).where(:user_id => id).first
	end

	def serializable_hash(options = nil)
		h = super({ only: [:id, :name] }.merge(options || {})).merge({
			:url => Rails.application.routes.url_helpers.user_path(nil, self, {:only_path => false})
		})
		# rename listable_scripts to scripts
		if !h['listable_scripts'].nil?
			h['scripts'] = h['listable_scripts']
			h.delete('listable_scripts')
		end
		return h
	end

	# Returns the user's preferred locale code, if we have that locale available, otherwise nil.
	def available_locale_code
		return nil if locale.nil?
		return nil if !locale.ui_available
		return locale.code
	end

	protected

	def password_required?
		self.new_record? && self.identities.empty?
	end
end
