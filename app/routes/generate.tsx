import { ActionFunction } from '@remix-run/node';
import { Form, useActionData, useNavigation } from '@remix-run/react';
import { useEffect, useState, Suspense, lazy } from 'react';
import ToneSelector from '~/components/ToneSelector';
import EnhancedTextInput from '~/components/EnhancedTextInput';
import { azureOpenAIService } from '../services/openai-service';

const PreviewCard = lazy(() => import('~/components/PreviewCard'));
const SuccessNotification = lazy(
  () => import('~/components/SuccessNotification')
);
const LoadingOverlay = lazy(() => import('~/components/LoadingOverlay'));

type ToneOfVoice = 'technical' | 'casual' | 'motivational';

type GeneratedContent = {
  mainContent: string;
  hashtags: string[];
  insights: string[];
};

type ActionData = {
  success?: boolean;
  content?: GeneratedContent;
  error?: string;
};

export const action: ActionFunction = async ({ request }) => {
  const formData = await request.formData();
  const topic = formData.get('topic');
  const tone = formData.get('tone');
  const keywords = formData.get('keywords');

  if (!topic || typeof topic !== 'string') {
    return new Response(JSON.stringify({ error: 'Topic is required.' }), {
      status: 400,
      headers: {
        'Content-Type': 'application/json; charset=utf-8',
      },
    });
  }

  try {
    const generatedContent = await azureOpenAIService.generateMicroblogContent(
      topic,
      tone?.toString() || 'casual',
      keywords?.toString()
    );

    return new Response(
      JSON.stringify({ success: true, content: generatedContent }),
      {
        status: 200,
        headers: {
          'Content-Type': 'application/json; charset=utf-8',
        },
      }
    );
  } catch {
    return new Response(
      JSON.stringify({ error: 'Failed to generate content.' }),
      {
        status: 500,
        headers: {
          'Content-Type': 'application/json; charset=utf-8',
        },
      }
    );
  }
};

export default function Generate() {
  const [formState, setFormState] = useState({
    topic: '',
    tone: 'casual',
    keywords: '',
  });

  const [showSuccess, setShowSuccess] = useState(false);
  const navigation = useNavigation();
  const actionData = useActionData<ActionData>();
  const isGenerating = navigation.state === 'submitting';

  useEffect(() => {
    if (actionData?.success) {
      setShowSuccess(true);
      setTimeout(() => setShowSuccess(false), 3000);
    }
  }, [actionData?.success]);

  // Função para resetar o formulário
  const handleNewPost = () => {
    setFormState({ topic: '', tone: 'casual', keywords: '' });
  };

  return (
    <div className='min-h-screen bg-gray-50 dark:bg-gray-900 py-12'>
      <div className='max-w-4xl mx-auto px-4 sm:px-6 lg:px-8'>
        {/* Header */}
        <div className='text-center mb-12'>
          <h1
            className='text-4xl font-bold bg-clip-text text-transparent bg-linear-to-r 
            from-gray-900 to-gray-700 dark:from-white dark:to-gray-200'
          >
            Generate Your Microblog
          </h1>
          <p className='mt-4 text-lg text-gray-600 dark:text-gray-300'>
            Fill in the details below and let AI create engaging content for you
          </p>
        </div>

        {/* Main Form */}
        <div className='bg-white dark:bg-gray-800 rounded-xl shadow-lg p-8'>
          <Form method='post' className='space-y-8'>
            <EnhancedTextInput
              label='Topic or Main Idea'
              name='topic'
              value={formState.topic}
              onChange={(e: React.ChangeEvent<HTMLInputElement>) =>
                setFormState({ ...formState, topic: e.target.value })
              }
              placeholder='Enter a topic'
              required
              maxLength={100}
            />
            <ToneSelector
              value={formState.tone as ToneOfVoice}
              onChange={(tone: ToneOfVoice) =>
                setFormState({ ...formState, tone })
              }
            />
            <EnhancedTextInput
              label='Keywords (optional)'
              name='keywords'
              value={formState.keywords}
              onChange={(e: React.ChangeEvent<HTMLInputElement>) =>
                setFormState({ ...formState, keywords: e.target.value })
              }
              placeholder='Enter keywords, separated by commas'
              maxLength={150}
            />
            <button
              type='submit'
              disabled={isGenerating}
              className='w-full py-4 px-6 bg-blue-600 text-white rounded-lg font-medium
                transition-all duration-300 transform hover:scale-[1.02] hover:bg-blue-700
                disabled:opacity-50 disabled:cursor-not-allowed disabled:hover:scale-100
                flex items-center justify-center space-x-2 shadow-lg hover:shadow-xl'
            >
              {isGenerating ? 'Generating...' : 'Generate Content'}
            </button>
          </Form>

          {/* Display preview of generated output */}
          <Suspense fallback={<div>Loading preview...</div>}>
            <PreviewCard />
          </Suspense>

          {/* Display the content returned by the API */}
          {actionData?.success && actionData.content && (
            <div className='mt-8 p-4 rounded-sm bg-green-50 border border-green-200'>
              <h2 className='text-lg font-bold mb-2'>Microblog generated</h2>
              <p>
                <strong>Text:</strong> {actionData.content.mainContent}
              </p>
              <p>
                <strong>Hashtags:</strong>{' '}
                {actionData.content.hashtags.join(', ')}
              </p>
              <div>
                <strong>Insights:</strong>
                <ul className='list-disc list-inside'>
                  {actionData.content.insights.map((insight, index) => (
                    <li key={index}>{insight}</li>
                  ))}
                </ul>
              </div>

              {/* Novo botão para iniciar uma nova postagem */}
              <button
                onClick={handleNewPost}
                className='mt-4 px-6 py-3 bg-gray-700 text-white rounded-lg font-medium
                  transition-all duration-300 transform hover:scale-[1.02] hover:bg-gray-800
                  flex items-center justify-center space-x-2 shadow-lg hover:shadow-xl'
              >
                New Post
              </button>
            </div>
          )}
        </div>

        {/* Error display if Action returns an error */}
        {actionData?.error && (
          <div
            className='mt-6 p-4 bg-red-50 dark:bg-red-900/20 text-red-600 
          dark:text-red-400 rounded-lg'
          >
            {actionData.error}
          </div>
        )}

        {/* Loading and notification of success */}
        <Suspense fallback={null}>
          {isGenerating && <LoadingOverlay />}
        </Suspense>

        <Suspense fallback={null}>
          {showSuccess && <SuccessNotification />}
        </Suspense>
      </div>
    </div>
  );
}
